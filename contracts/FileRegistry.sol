
// adapted from github.com/Azure-Samples/blockchain-devkit/blob/master/accelerators
// adapted by Alexandria Pawlik, May 2019

pragma solidity ^0.5.0;

contract FileRegistry 
{
  enum StateType { Created, Open, Closed}
  StateType public State;

  FileStruct[] public Files;

  mapping(string => FileStruct) internal FileIdLookup;
  mapping(address => FileStruct) internal FileContractAddressLookup;

  string public Name;
  string public Description;

  struct FileStruct 
  { 
    address FileContractAddress;
    string FileId; 
    uint Index;
  }

  address[] internal FileAddressIndex;
  string[] internal FileIdIndex;

  constructor (string name, string description) 
  public 
  {
    Name = name;
    Description = description;
    State = StateType.Created;
  }

  function OpenRegistry() 
  public 
  {
    State = StateType.Open;        
  }

  function CloseRegistry() 
  public 
  {
    State = StateType.Closed;
  }

  //Lookup to see if a contract address for a File contract is already registered
  function IsRegisteredFileContractAddress(address FileContractAddress)
  public 
  view
  returns(bool isRegistered) 
  {
    if(FileAddressIndex.length == 0) return false;
    
    return (FileAddressIndex[FileContractAddressLookup[FileContractAddress].Index] == FileContractAddress);
  }


  //Look up to see if this File reg is registered
  function IsRegisteredFileId(bytes32 FileId)
  public 
  view
  returns(bool isRegistered) 
  {
    if(FileIdIndex.length == 0) return false;

    string memory FileIdString = bytes32ToString(FileId);
    string memory FileIdInternalString = FileIdIndex[FileIdLookup[FileIdString].Index];

    return (compareStrings(FileIdInternalString, FileIdString));
  }
  
  //Look up to see if this File reg is registered
  function IsRegisteredFileId(string FileId)
  public 
  view
  returns(bool isRegistered) 
  {
    if(FileIdIndex.length == 0) return false;
  
    string memory FileIdInternalString = FileIdIndex[FileIdLookup[FileId].Index];
    
    return (compareStrings(FileIdInternalString, FileId));
  }

  function RegisterFile(address FileContractAddress, string FileId) 
  public
  {
    if (State != StateType.Open) revert();
    if(IsRegisteredFileContractAddress(FileContractAddress)) revert(); 
   
    //Add lookup by address
    FileContractAddressLookup[FileContractAddress].FileContractAddress = FileContractAddress;

    FileContractAddressLookup[FileContractAddress].FileId = FileId;
    FileContractAddressLookup[FileContractAddress].Index = FileAddressIndex.push(FileContractAddress)-1;
   
    //Add look up by reg number
    FileIdLookup[FileId].FileContractAddress = FileContractAddress;
  
    FileIdLookup[FileId].FileId = FileId;
    FileIdLookup[FileId].Index = FileIdIndex.push(FileId)-1;
  }

  // function GetFileByAddress(address FileContractAddress)
  // public 
  // view
  // returns(bytes32 FileId)
  // {
  //     if(!IsRegisteredFileContractAddress(FileContractAddress)) revert(); 

  //     return stringToBytes32(FileContractAddressLookup[FileContractAddress].FileId);
  // } 
  
  // function GetFileByFileId(bytes32 FileId)
  // public 
  // view
  // returns(address FileContractAddress)
  // {
  //     string memory FileIdString = bytes32ToString(FileId);
  //     if(!IsRegisteredFileId(FileId)) revert();

  //     return  FileIdLookup[FileIdString].FileContractAddress;
  // } 

  function GetNumberOfRegisteredFiles() 
  public
  view
  returns (uint)
  {
    return FileAddressIndex.length;
  }

  function GetFileAtIndex(uint index)
  public
  view
  returns (address)
  {
    return FileAddressIndex[index];
  }

  function GetName()
  public
  view
  returns (string)
  {
    return Name;
  }

  
  //-----------------------------------------------------
  // Supporting Functions
  //-----------------------------------------------------
  
  // function stringToBytes32(string memory source) 
  // internal 
  // pure 
  // returns(bytes32 result) 
  // {
  //     bytes memory tempEmptyStringTest = bytes(source);
  //     if (tempEmptyStringTest.length == 0) 
  //     {
  //         return 0x0;
  //     }

  //     assembly 
  //     {
  //         result := mload(add(source, 32))
  //     }
  // }
  
  function bytes32ToString(bytes32 x)  
  internal 
  pure 
  returns(string) 
  {
    bytes memory bytesString = new bytes(32);
    uint charCount = 0;
    for (uint j = 0; j < 32; j++) 
    {
      byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
      if (char != 0) 
      {
        bytesString[charCount] = char;
        charCount++;
      }
    }

    bytes memory bytesStringTrimmed = new bytes(charCount);
    for (j = 0; j < charCount; j++) 
    {
      bytesStringTrimmed[j] = bytesString[j];
    }

    return string(bytesStringTrimmed);  
  }

  function compareStrings(string a, string b) 
  internal 
  pure 
  returns(bool)
  {
    return keccak256(bytes(a)) == keccak256(bytes(b));
  }

}

contract File {

  // Registry
  FileRegistry MyFileRegistry;
  address public RegistryAddress;
  string public RegistryName;  // name of the registry that the file is located in

  //Set of States
  enum StateType { New, Matched, Unique, Deleted}
  StateType public State;

  //File Properties
  string public FileName;  // name of the file in OneDrive
  // address public FileManager; // agent that processed the File
  string public FileId; //identifier for the File, stored off chain
  string public Location; //The location of the file, e.g. URI
  string public FileHash; // text here, but could be an Id
  string public FileMetadataHash; // text here, but coudl be an Id
  string public ContentType; // text, represents the color of the File
  string public Etag; // text, represents the color of the File

  string public ProcessedDateTime; // MM/DD/YY HH:MM:SS
  string public DeletedDateTime; // MM/DD/YY HH:MM:SS

  // event MatchedFile(string fileName, string location);
  // event UniqueFile(string fileName, string location);
  // event DeletedFile(string fileName, string location);

  constructor (string registryAddress, string filename, string fileId, string location, 
    string fileHash, string fileMetadataHash, string contentType, string etag) 
  public 
  {
    FileName = filename;
    FileId = fileId;
    Location = location;
    FileHash = fileHash;
    FileMetadataHash = fileMetadataHash;
    ContentType = contentType;
    Etag = etag;
    ProcessedDateTime = parseTimestamp();
    RegistryAddress = stringToAddress(registryAddress);

    MyFileRegistry = FileRegistry(RegistryAddress);
    RegistryName = MyFileRegistry.GetName();

     //If this file id is already registered, revert
     if (MyFileRegistry.IsRegisteredFileId(stringToBytes32(FileId))) revert();

    //NOTE - Can hardcode registry if registry previously deployed to the chain to avoid having to call AssignRegistry
    MyFileRegistry.RegisterFile(address(this), FileId);
   
    State = StateType.New;
  }

  // function RegisterFile(address registryAddress) 
  // public 
  // {
  // 	// only assign if there isn't one assigned already
  // 	if (RegistryAddress != 0x0) revert(); 
  // 	RegistryAddress = registryAddress;
    
  // 	if (State != StateType.New) revert();
    
  // 	MyFileRegistry = FileRegistry(RegistryAddress);
    
  // 	//Check to see if the File is already registered
  // 	if (MyFileRegistry.IsRegisteredFileContractAddress(address(this))) revert();
    
  // 	MyFileRegistry.RegisterFile32(address(this), stringToBytes32(FileId));
  // }

  function Verify() 
  public 
  {
    uint count = 0;

    // check to see if identical file exists in registry
    for (uint idx = 0; idx < MyFileRegistry.GetNumberOfRegisteredFiles(); idx++) {
      if ( File(MyFileRegistry.GetFileAtIndex(idx)).NotDeleted() &&
        compareStrings(File(MyFileRegistry.GetFileAtIndex(idx)).GetFileHash(), FileHash) )
      {
        count++;
      }
    }

    // should always count 1 for itself
    if (count > 1) 
    {
      // if a real match is found
      MakeMatched();
      // emit MatchedFile(FileName, Location);
    } else 
    {
      // identical file has not been found
      MakeUnique();
      // emit UniqueFile(FileName, Location);
    }
  }

  function MakeMatched() 
  public
  {
    State = StateType.Matched;
  }

  function MakeUnique()
  public
  {
    State = StateType.Unique;
  }

  function Delete() 
  public 
  {
    State = StateType.Deleted;
    DeletedDateTime = parseTimestamp();
    // emit DeletedFile(FileName, Location);
  }

  function GetFileHash() 
  public 
  view 
  returns(string) 
  {
    return FileHash;
  }

  // returns true if the file has not been deleted
  function NotDeleted()
  public
  view
  returns(bool)
  {
    return State != StateType.Deleted;
  }

  function GetFileMetadataHash() 
  public 
  view 
  returns(string filemetadatahash) 
  {
    return FileMetadataHash;
  }

  //-----------------------------------------------------
  // Supporting Functions
  //-----------------------------------------------------
    
  function stringToBytes32(string memory source) 
  internal 
  pure 
  returns(bytes32 result) 
  {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) 
    {
      return 0x0;
    }

    assembly 
    {
      result := mload(add(source, 32))
    }
  }
  
  // function bytes32ToString(bytes32 x) 
  // internal 
  // pure 
  // returns(string) 
  // {
  //     bytes memory bytesString = new bytes(32);
  //     uint charCount = 0;
  //     for (uint j  = 0; j < 32; j++) 
  //     {
  //         byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
  //         if (char != 0) 
  //         {
  //             bytesString[charCount] = char;
  //             charCount++;
  //         }
  //     }

  //     bytes memory bytesStringTrimmed = new bytes(charCount);
  //     for (j = 0; j < charCount; j++) 
  //     {
  //         bytesStringTrimmed[j] = bytesString[j];
  //     }

  //     return string(bytesStringTrimmed); 
  // }

  function compareStrings(string a, string b) 
  internal 
  pure 
  returns(bool)
  {
    return keccak256(bytes(a)) == keccak256(bytes(b));
  }

  function stringToAddress(string _a) 
  internal 
  pure 
  returns(address)
  {
    bytes memory tmp = bytes(_a);
    uint160 iaddr = 0;
    uint160 b1;
    uint160 b2;
    
    for (uint i=2; i<2+2*20; i+=2)
    {
      iaddr *= 256;
      b1 = uint160(tmp[i]);
      b2 = uint160(tmp[i+1]);
      if ((b1 >= 97)&&(b1 <= 102)) b1 -= 87;
      else if ((b1 >= 48)&&(b1 <= 57)) b1 -= 48;
      if ((b2 >= 97)&&(b2 <= 102)) b2 -= 87;
      else if ((b2 >= 48)&&(b2 <= 57)) b2 -= 48;
      iaddr += (b1*16+b2);
    }

    return address(iaddr);
  }

  //-----------------------------------------------------
  // Type Manipulation Supporting Functions
  // adapted from github.com/oraclize/ethereum-api
  //-----------------------------------------------------

  function uintToString(uint i) 
  internal 
  pure 
  returns (string)
  {
    if (i == 0) return "0";

    uint j = i;
    uint length;
    while (j != 0)
    {
      length++;
      j /= 10;
    }

    bytes memory bstr = new bytes(length);
    uint k = length - 1;
    while (i != 0)
    {
      bstr[k--] = byte(48 + i % 10);
      i /= 10;
    }

    return string(bstr);
  }

  function strConcat(string _a, string _b, string _c, string _d, string _e) 
  internal 
  pure
  returns (string)
  {
    bytes memory _ba = bytes(_a);
    bytes memory _bb = bytes(_b);
    bytes memory _bc = bytes(_c);
    bytes memory _bd = bytes(_d);
    bytes memory _be = bytes(_e);

    string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
    bytes memory babcde = bytes(abcde);

    uint k = 0;

    for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
    for (i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
    for (i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
    for (i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
    for (i = 0; i < _be.length; i++) babcde[k++] = _be[i];
    
    return string(babcde);
  }

  //-----------------------------------------------------
  // DateTime Supporting Functions
  // adapted from github.com/pipermerriam/ethereum-datetime/blob/master/contracts/DateTime.sol
  //-----------------------------------------------------

  uint constant DAY_IN_SECONDS = 86400;
  uint constant YEAR_IN_SECONDS = 31536000;
  uint constant LEAP_YEAR_IN_SECONDS = 31622400;

  uint16 constant ORIGIN_YEAR = 1970;

  struct _datetime 
  {
    uint16 year;
    uint8 year2;
    uint8 month;
    uint8 day;
    uint8 hour;
    uint8 minute;
    uint8 second;
  }

  // returns current timestamp as string in form MM/DD/YY HH:MM:SS
  function parseTimestamp() 
  internal 
  view 
  returns (string datetime) 
  {
    _datetime dt;

    uint timestamp = now;
    uint secondsAccountedFor = 0;
    uint buf;

    uint8 i;

    // Year
    dt.year = getYear(timestamp);
    buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
    secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);
    dt.year2 = uint8(dt.year % 100);

    // Month
    uint secondsInMonth;
    for (i = 1; i <= 12; i++) 
    {
      secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
      if (secondsInMonth + secondsAccountedFor > timestamp) 
      {
        dt.month = i;
        break;
      }
      secondsAccountedFor += secondsInMonth;
    }

    // Day
    for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) 
    {
      if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) 
      {
        dt.day = i;
        break;
      }
      secondsAccountedFor += DAY_IN_SECONDS;
    }

    // Hour
    dt.hour = uint8((timestamp / 60 / 60) % 24);

    // Minute
    dt.minute = uint8((timestamp / 60) % 60);

    // Second
    dt.second = uint8(timestamp % 60);

    datetime = dtToString(dt);
  }

  function dtToString(_datetime dt)
  internal
  pure
  returns (string datetime)
  {
    string memory hourStr;
    string memory minuteStr;
    string memory secondStr;
    string memory monthStr;
    string memory dayStr;

    // add filler 0s
    if (dt.month < 10)
    {
      monthStr = strConcat("0", uintToString(dt.month), "","", "");
    } else
    {
      monthStr = uintToString(dt.month);
    }
    if (dt.day < 10)
    {
      dayStr = strConcat("0", uintToString(dt.day), "","", "");
    } else
    {
      dayStr = uintToString(dt.day);
    }
    if (dt.hour < 10)
    {
      hourStr = strConcat("0", uintToString(dt.hour), "","", "");
    } else
    {
      hourStr = uintToString(dt.hour);
    }
    if (dt.minute < 10)
    {
      minuteStr = strConcat("0", uintToString(dt.minute), "","", "");
    } else
    {
      minuteStr = uintToString(dt.minute);
    }
    if (dt.second < 10)
    {
      secondStr = strConcat("0", uintToString(dt.second), "","", "");
    } else
    {
      secondStr = uintToString(dt.second);
    }

    // convert struct to string
    datetime = strConcat(
      strConcat(monthStr, "/", dayStr, "/", uintToString(dt.year2)), 
      " ", 
      strConcat(hourStr, ":", minuteStr, ":", secondStr), 
      "", ""
    );
  }

  function isLeapYear(uint16 year) 
  internal
  pure
  returns (bool) 
  {
    if (year % 4 != 0) 
    {
      return false;
    }
    if (year % 100 != 0) 
    {
      return true;
    }
    if (year % 400 != 0) 
    {
      return false;
    }
    return true;
  }

  function leapYearsBefore(uint year) 
  internal 
  pure 
  returns (uint) 
  {
    year -= 1;
    return year / 4 - year / 100 + year / 400;
  }

  function getDaysInMonth(uint8 month, uint16 year) 
  internal
  pure 
  returns (uint8) 
  {
    if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) 
    {
      return 31;
    } else if (month == 4 || month == 6 || month == 9 || month == 11) 
    {
      return 30;
    } else if (isLeapYear(year)) 
    {
      return 29;
    } else 
    {
      return 28;
    }
  }

  function getYear(uint timestamp) 
  internal
  pure 
  returns (uint16) 
  {
    uint secondsAccountedFor = 0;
    uint16 year;
    uint numLeapYears;

    // Year
    year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
    numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
    secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

    while (secondsAccountedFor > timestamp) 
    {
      if (isLeapYear(uint16(year - 1))) 
      {
        secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
      } else 
      {
        secondsAccountedFor -= YEAR_IN_SECONDS;
      }
      year -= 1;
    }
    return year;
  }

}