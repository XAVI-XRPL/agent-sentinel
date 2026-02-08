// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SentinelRequests
 * @author Agent Sentinel (Autonomous AI Auditor on XRPL EVM)
 * @notice Request and pay for smart contract audits
 * @dev Queue system for audit requests with XRP payments
 */
contract SentinelRequests is Ownable, ReentrancyGuard {
    
    // ============ Enums ============
    
    enum RequestStatus {
        Pending,        // 0 - Waiting to be picked up
        InProgress,     // 1 - Auditor working on it
        Completed,      // 2 - Audit finished
        Refunded        // 3 - Payment returned
    }
    
    // ============ Structs ============
    
    struct AuditRequest {
        uint256 id;
        address requester;
        address contractToAudit;
        uint256 payment;
        RequestStatus status;
        uint256 requestedAt;
        uint256 completedAt;
        uint256 reportId;           // Links to SentinelRegistry report
    }
    
    // ============ State ============
    
    /// @notice All audit requests
    mapping(uint256 => AuditRequest) public requests;
    
    /// @notice Total requests created
    uint256 public requestCount;
    
    /// @notice Minimum audit fee (5 XRP)
    uint256 public minAuditFee = 5 ether;
    
    /// @notice Refund timeout (7 days)
    uint256 public refundTimeout = 7 days;
    
    /// @notice Registry contract address
    address public registry;
    
    /// @notice Auditor address (Sentinel)
    address public auditor;
    
    /// @notice Requests by requester
    mapping(address => uint256[]) public requestsByRequester;
    
    /// @notice Total fees collected
    uint256 public totalFeesCollected;
    
    /// @notice Free audit contracts (Xavi's deployments)
    mapping(address => bool) public freeAuditEligible;
    
    // ============ Events ============
    
    event AuditRequested(
        uint256 indexed requestId,
        address indexed requester,
        address indexed contractToAudit,
        uint256 payment
    );
    
    event AuditStarted(uint256 indexed requestId);
    event AuditCompleted(uint256 indexed requestId, uint256 indexed reportId);
    event AuditRefunded(uint256 indexed requestId);
    event FreeAuditGranted(address indexed contractAddress);
    
    // ============ Modifiers ============
    
    modifier onlyAuditor() {
        require(msg.sender == auditor, "SentinelRequests: not auditor");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _registry) Ownable(msg.sender) {
        registry = _registry;
        auditor = msg.sender; // Deployer is the auditor (Sentinel)
    }
    
    // ============ Public Functions ============
    
    /// @notice Request an audit for a contract
    /// @param contractToAudit Address of the contract to audit
    function requestAudit(address contractToAudit) external payable nonReentrant {
        require(contractToAudit != address(0), "SentinelRequests: zero address");
        
        // Check if contract is eligible for free audit
        if (!freeAuditEligible[contractToAudit]) {
            require(msg.value >= minAuditFee, "SentinelRequests: insufficient fee");
        }
        
        requestCount++;
        uint256 requestId = requestCount;
        
        requests[requestId] = AuditRequest({
            id: requestId,
            requester: msg.sender,
            contractToAudit: contractToAudit,
            payment: msg.value,
            status: RequestStatus.Pending,
            requestedAt: block.timestamp,
            completedAt: 0,
            reportId: 0
        });
        
        requestsByRequester[msg.sender].push(requestId);
        
        if (msg.value > 0) {
            totalFeesCollected += msg.value;
        }
        
        emit AuditRequested(requestId, msg.sender, contractToAudit, msg.value);
    }
    
    /// @notice Refund a request if not started within timeout
    /// @param requestId ID of the request to refund
    function refundRequest(uint256 requestId) external nonReentrant {
        AuditRequest storage req = requests[requestId];
        
        require(req.id != 0, "SentinelRequests: invalid request");
        require(req.status == RequestStatus.Pending, "SentinelRequests: not pending");
        require(
            block.timestamp >= req.requestedAt + refundTimeout,
            "SentinelRequests: timeout not reached"
        );
        require(
            msg.sender == req.requester || msg.sender == owner(),
            "SentinelRequests: not authorized"
        );
        
        req.status = RequestStatus.Refunded;
        
        if (req.payment > 0) {
            totalFeesCollected -= req.payment;
            (bool sent, ) = payable(req.requester).call{value: req.payment}("");
            require(sent, "SentinelRequests: refund failed");
        }
        
        emit AuditRefunded(requestId);
    }
    
    // ============ Auditor Functions ============
    
    /// @notice Start working on an audit request
    /// @param requestId ID of the request to start
    function startAudit(uint256 requestId) external onlyAuditor {
        AuditRequest storage req = requests[requestId];
        
        require(req.id != 0, "SentinelRequests: invalid request");
        require(req.status == RequestStatus.Pending, "SentinelRequests: not pending");
        
        req.status = RequestStatus.InProgress;
        
        emit AuditStarted(requestId);
    }
    
    /// @notice Complete an audit and link the report
    /// @param requestId ID of the request to complete
    /// @param reportId ID of the report in SentinelRegistry
    function completeAudit(uint256 requestId, uint256 reportId) external onlyAuditor {
        AuditRequest storage req = requests[requestId];
        
        require(req.id != 0, "SentinelRequests: invalid request");
        require(
            req.status == RequestStatus.Pending || req.status == RequestStatus.InProgress,
            "SentinelRequests: invalid status"
        );
        
        req.status = RequestStatus.Completed;
        req.completedAt = block.timestamp;
        req.reportId = reportId;
        
        emit AuditCompleted(requestId, reportId);
    }
    
    // ============ View Functions ============
    
    /// @notice Get a specific request
    function getRequest(uint256 requestId) external view returns (AuditRequest memory) {
        require(requestId > 0 && requestId <= requestCount, "SentinelRequests: invalid ID");
        return requests[requestId];
    }
    
    /// @notice Get all pending request IDs
    function getPendingRequests() external view returns (uint256[] memory) {
        uint256 pendingCount = 0;
        for (uint256 i = 1; i <= requestCount; i++) {
            if (requests[i].status == RequestStatus.Pending) {
                pendingCount++;
            }
        }
        
        uint256[] memory pending = new uint256[](pendingCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= requestCount; i++) {
            if (requests[i].status == RequestStatus.Pending) {
                pending[index] = i;
                index++;
            }
        }
        
        return pending;
    }
    
    /// @notice Get requests by a specific requester
    function getMyRequests(address requester) external view returns (uint256[] memory) {
        return requestsByRequester[requester];
    }
    
    /// @notice Get contract balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // ============ Admin Functions ============
    
    /// @notice Set minimum audit fee
    function setMinAuditFee(uint256 _minFee) external onlyOwner {
        minAuditFee = _minFee;
    }
    
    /// @notice Set refund timeout
    function setRefundTimeout(uint256 _timeout) external onlyOwner {
        refundTimeout = _timeout;
    }
    
    /// @notice Set auditor address
    function setAuditor(address _auditor) external onlyOwner {
        require(_auditor != address(0), "SentinelRequests: zero address");
        auditor = _auditor;
    }
    
    /// @notice Grant free audit eligibility (for Xavi's contracts)
    function grantFreeAudit(address contractAddress) external onlyOwner {
        freeAuditEligible[contractAddress] = true;
        emit FreeAuditGranted(contractAddress);
    }
    
    /// @notice Withdraw collected fees
    function withdrawFees(address to) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "SentinelRequests: no balance");
        (bool sent, ) = payable(to).call{value: balance}("");
        require(sent, "SentinelRequests: withdraw failed");
    }
}
