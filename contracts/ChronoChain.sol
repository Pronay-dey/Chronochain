// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ChronoChain
 * @dev Time‑indexed on‑chain timeline of events and checkpoints
 * @notice Users can record timestamped events, create time-locked notes, and query chronological history
 */
contract ChronoChain {
    
    // State variables
    address public owner;
    uint256 public totalEvents;
    uint256 public totalUsers;
    
    struct ChronoEvent {
        address creator;
        uint256 createdAt;      // block.timestamp when recorded
        uint256 effectiveTime;  // logical time for the event (can be now or future)
        string  title;
        string  data;           // short JSON/string payload or reference
        bool    isLocked;       // true if cannot be edited before effectiveTime
        bool    isActive;
    }
    
    // eventId => ChronoEvent
    mapping(uint256 => ChronoEvent) public eventsById;
    
    // user => list of eventIds
    mapping(address => uint256[]) public eventsOfUser;
    
    // user => seen flag (for stats)
    mapping(address => bool) public isKnownUser;
    
    // Events
    event EventRecorded(
        uint256 indexed eventId,
        address indexed creator,
        uint256 createdAt,
        uint256 effectiveTime,
        string title
    );
    
    event EventUpdated(
        uint256 indexed eventId,
        string newTitle,
        string newData,
        uint256 updatedAt
    );
    
    event EventDeactivated(
        uint256 indexed eventId,
        address indexed caller,
        uint256 timestamp
    );
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier eventExists(uint256 eventId) {
        require(eventsById[eventId].creator != address(0), "Event does not exist");
        _;
    }
    
    modifier onlyCreator(uint256 eventId) {
        require(eventsById[eventId].creator == msg.sender, "Not event creator");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Function 1: Record a new event at current time
     * @param title Short title for the event
     * @param data Arbitrary metadata (e.g., JSON, URI, description)
     * @notice effectiveTime will be set to block.timestamp
     */
    function recordNow(string calldata title, string calldata data)
        external
        returns (uint256 eventId)
    {
        eventId = _createEvent(block.timestamp, title, data, false);
    }
    
    /**
     * @dev Function 2: Record a scheduled (future) event
     * @param effectiveTime The logical time for this event (must be >= now)
     * @param title Short title
     * @param data Arbitrary metadata
     * @param lockUntilEffective If true, the event cannot be edited until effectiveTime
     * @notice Useful for timelined plans, releases, or reminders
     */
    function recordScheduled(
        uint256 effectiveTime,
        string calldata title,
        string calldata data,
        bool lockUntilEffective
    )
        external
        returns (uint256 eventId)
    {
        require(effectiveTime >= block.timestamp, "Effective time in past");
        eventId = _createEvent(effectiveTime, title, data, lockUntilEffective);
    }
    
    /**
     * @dev Internal helper to create a ChronoEvent
     */
    function _createEvent(
        uint256 effectiveTime,
        string calldata title,
        string calldata data,
        bool lockFlag
    )
        internal
        returns (uint256 eventId)
    {
        eventId = totalEvents;
        totalEvents += 1;
        
        if (!isKnownUser[msg.sender]) {
            isKnownUser[msg.sender] = true;
            totalUsers += 1;
        }
        
        eventsById[eventId] = ChronoEvent({
            creator: msg.sender,
            createdAt: block.timestamp,
            effectiveTime: effectiveTime,
            title: title,
            data: data,
            isLocked: lockFlag,
            isActive: true
        });
        
        eventsOfUser[msg.sender].push(eventId);
        
        emit EventRecorded(
            eventId,
            msg.sender,
            block.timestamp,
            effectiveTime,
            title
        );
    }
    
    /**
     * @dev Function 3: Update title/data of an existing event
     * @param eventId ID of the event
     * @param newTitle New title
     * @param newData New data
     * @notice If event is locked and effectiveTime is in the future, update is not allowed
     */
    function updateEvent(
        uint256 eventId,
        string calldata newTitle,
        string calldata newData
    )
        external
        eventExists(eventId)
        onlyCreator(eventId)
    {
        ChronoEvent storage e = eventsById[eventId];
        require(e.isActive, "Event inactive");
        
        if (e.isLocked) {
            require(block.timestamp >= e.effectiveTime, "Event locked until effective time");
        }
        
        e.title = newTitle;
        e.data = newData;
        
        emit EventUpdated(eventId, newTitle, newData, block.timestamp);
    }
    
    /**
     * @dev Function 4: Deactivate an event
     * @param eventId ID of the event
     * @notice Soft delete; keeps history but hides from active UIs
     */
    function deactivateEvent(uint256 eventId)
        external
        eventExists(eventId)
        onlyCreator(eventId)
    {
        require(eventsById[eventId].isActive, "Already inactive");
        eventsById[eventId].isActive = false;
        
        emit EventDeactivated(eventId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Function 5: Get full event info
     * @param eventId ID of the event
     */
    function getEvent(uint256 eventId)
        external
        view
        eventExists(eventId)
        returns (
            address creator,
            uint256 createdAt,
            uint256 effectiveTime,
            string memory title,
            string memory data,
            bool isLocked,
            bool isActive
        )
    {
        ChronoEvent memory e = eventsById[eventId];
        return (
            e.creator,
            e.createdAt,
            e.effectiveTime,
            e.title,
            e.data,
            e.isLocked,
            e.isActive
        );
    }
    
    /**
     * @dev Function 6: Get all event IDs created by a user
     * @param user Address to query
     */
    function getEventsOf(address user) external view returns (uint256[] memory) {
        return eventsOfUser[user];
    }
    
    /**
     * @dev Function 7: Check if an event is currently active and effective
     * @param eventId ID of the event
     * @return isLive True if active and block.timestamp >= effectiveTime
     */
    function isEventLive(uint256 eventId)
        external
        view
        eventExists(eventId)
        returns (bool isLive)
    {
        ChronoEvent memory e = eventsById[eventId];
        return e.isActive && block.timestamp >= e.effectiveTime;
    }
    
    /**
     * @dev Transfer contract ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
    
    /**
     * @dev Get basic stats
     * @return eventsCount Total events
     * @return usersCount Total unique creators
     */
    function getStats() external view returns (uint256 eventsCount, uint256 usersCount) {
        return (totalEvents, totalUsers);
    }
}
