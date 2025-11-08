Hash of data being timestamped
        address submitter;      Block timestamp when entry was recorded
        string metadataURI;     Array holding chronological entries
    Entry[] private entries;

    // Event emitted when a new entry is logged
    event EntryLogged(uint256 indexed entryIndex, bytes32 dataHash, address indexed submitter, uint256 timestamp, string metadataURI);

    /**
     * @dev Submit data hash with optional metadata, registering timestamp on-chain
     * @param dataHash Hash of data to timestamp (e.g., SHA-256)
     * @param metadataURI Optional URI (e.g., IPFS hash) with more info
     */
    function submitEntry(bytes32 dataHash, string calldata metadataURI) external {
        require(dataHash != bytes32(0), "Data hash required");

        Entry memory newEntry = Entry({
            dataHash: dataHash,
            submitter: msg.sender,
            timestamp: block.timestamp,
            metadataURI: metadataURI
        });

        entries.push(newEntry);

        emit EntryLogged(entries.length - 1, dataHash, msg.sender, block.timestamp, metadataURI);
    }

    /**
     * @dev Get total number of entries
     */
    function getEntryCount() external view returns (uint256) {
        return entries.length;
    }

    /**
     * @dev Retrieve entry details by index
     * @param index Entry index
     * @return dataHash Hash of data
     * @return submitter Address who submitted
     * @return timestamp Block timestamp when recorded
     * @return metadataURI Metadata URI string
     */
    function getEntry(uint256 index) external view returns (
        bytes32 dataHash,
        address submitter,
        uint256 timestamp,
        string memory metadataURI
    ) {
        require(index < entries.length, "Invalid entry index");

        Entry storage e = entries[index];
        return (e.dataHash, e.submitter, e.timestamp, e.metadataURI);
    }

    /**
     * @dev Verify an entry by index and data hash
     * @param index Entry index
     * @param dataHash Expected data hash
     * @return isValid True if entry at index matches data hash
     */
    function verifyEntry(uint256 index, bytes32 dataHash) external view returns (bool isValid) {
        require(index < entries.length, "Invalid entry index");
        return (entries[index].dataHash == dataHash);
    }
}
// 
End
// 
