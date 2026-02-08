// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SentinelRegistry
 * @author Agent Sentinel (Autonomous AI Auditor on XRPL EVM)
 * @notice On-chain registry of smart contract audit reports
 * @dev Immutable audit records with risk scoring and IPFS report links
 */
contract SentinelRegistry is Ownable, ReentrancyGuard {
    
    // ============ Enums ============
    
    enum RiskLevel {
        Critical,       // 0 - Severe vulnerabilities, do not use
        High,           // 1 - Major issues requiring fixes
        Medium,         // 2 - Notable concerns
        Low,            // 3 - Minor issues
        Informational,  // 4 - Suggestions only
        Clean           // 5 - No issues found
    }
    
    // ============ Structs ============
    
    struct AuditReport {
        uint256 id;
        address contractAudited;
        address auditor;
        uint256 timestamp;
        uint256 overallScore;       // 0-100 (100 = perfect)
        string reportHash;          // IPFS CID of full report
        RiskLevel riskLevel;
        uint256 issuesFound;
        uint256 criticalCount;
        uint256 highCount;
        uint256 mediumCount;
        uint256 lowCount;
        bool verified;
    }
    
    // ============ State ============
    
    /// @notice All audit reports
    mapping(uint256 => AuditReport) public reports;
    
    /// @notice Total reports published
    uint256 public reportCount;
    
    /// @notice Reports by contract address
    mapping(address => uint256[]) public reportsByContract;
    
    /// @notice Registered auditors
    mapping(address => bool) public isAuditor;
    
    /// @notice Auditor names
    mapping(address => string) public auditorNames;
    
    // ============ Events ============
    
    event ReportPublished(
        uint256 indexed reportId,
        address indexed contractAudited,
        address indexed auditor,
        uint256 score,
        RiskLevel riskLevel
    );
    
    event AuditorRegistered(address indexed auditor, string name);
    event AuditorRemoved(address indexed auditor);
    
    // ============ Modifiers ============
    
    modifier onlyAuditor() {
        require(isAuditor[msg.sender], "SentinelRegistry: not an auditor");
        _;
    }
    
    // ============ Constructor ============
    
    constructor() Ownable(msg.sender) {
        // Register deployer as first auditor (Sentinel)
        isAuditor[msg.sender] = true;
        auditorNames[msg.sender] = "Agent Sentinel";
        emit AuditorRegistered(msg.sender, "Agent Sentinel");
    }
    
    // ============ Auditor Functions ============
    
    /// @notice Publish a new audit report
    /// @param contractAudited Address of the audited contract
    /// @param overallScore Security score 0-100
    /// @param reportHash IPFS CID of the full report
    /// @param riskLevel Overall risk assessment
    /// @param issuesFound Total number of issues
    /// @param criticalCount Number of critical issues
    /// @param highCount Number of high severity issues
    /// @param mediumCount Number of medium severity issues
    /// @param lowCount Number of low severity issues
    /// @return reportId The ID of the published report
    function publishReport(
        address contractAudited,
        uint256 overallScore,
        string calldata reportHash,
        RiskLevel riskLevel,
        uint256 issuesFound,
        uint256 criticalCount,
        uint256 highCount,
        uint256 mediumCount,
        uint256 lowCount
    ) external onlyAuditor returns (uint256 reportId) {
        require(contractAudited != address(0), "SentinelRegistry: zero address");
        require(overallScore <= 100, "SentinelRegistry: invalid score");
        require(bytes(reportHash).length > 0, "SentinelRegistry: empty report hash");
        
        reportCount++;
        reportId = reportCount;
        
        reports[reportId] = AuditReport({
            id: reportId,
            contractAudited: contractAudited,
            auditor: msg.sender,
            timestamp: block.timestamp,
            overallScore: overallScore,
            reportHash: reportHash,
            riskLevel: riskLevel,
            issuesFound: issuesFound,
            criticalCount: criticalCount,
            highCount: highCount,
            mediumCount: mediumCount,
            lowCount: lowCount,
            verified: true
        });
        
        reportsByContract[contractAudited].push(reportId);
        
        emit ReportPublished(reportId, contractAudited, msg.sender, overallScore, riskLevel);
    }
    
    // ============ View Functions ============
    
    /// @notice Get a specific report
    function getReport(uint256 reportId) external view returns (AuditReport memory) {
        require(reportId > 0 && reportId <= reportCount, "SentinelRegistry: invalid report ID");
        return reports[reportId];
    }
    
    /// @notice Get all report IDs for a contract
    function getReportsByContract(address contract_) external view returns (uint256[] memory) {
        return reportsByContract[contract_];
    }
    
    /// @notice Get the latest report for a contract
    function getLatestReport(address contract_) external view returns (AuditReport memory) {
        uint256[] memory ids = reportsByContract[contract_];
        require(ids.length > 0, "SentinelRegistry: no reports for contract");
        return reports[ids[ids.length - 1]];
    }
    
    /// @notice Get the audit score for a contract (latest report)
    function getAuditScore(address contract_) external view returns (uint256) {
        uint256[] memory ids = reportsByContract[contract_];
        if (ids.length == 0) return 0;
        return reports[ids[ids.length - 1]].overallScore;
    }
    
    /// @notice Check if a contract has been audited
    function isAudited(address contract_) external view returns (bool) {
        return reportsByContract[contract_].length > 0;
    }
    
    /// @notice Get total number of contracts audited
    function getAuditedContractsCount() external view returns (uint256 count) {
        // This is an approximation - counts reports not unique contracts
        return reportCount;
    }
    
    // ============ Admin Functions ============
    
    /// @notice Register a new auditor
    function registerAuditor(address auditor, string calldata name) external onlyOwner {
        require(auditor != address(0), "SentinelRegistry: zero address");
        require(!isAuditor[auditor], "SentinelRegistry: already registered");
        
        isAuditor[auditor] = true;
        auditorNames[auditor] = name;
        
        emit AuditorRegistered(auditor, name);
    }
    
    /// @notice Remove an auditor
    function removeAuditor(address auditor) external onlyOwner {
        require(isAuditor[auditor], "SentinelRegistry: not an auditor");
        
        isAuditor[auditor] = false;
        delete auditorNames[auditor];
        
        emit AuditorRemoved(auditor);
    }
}
