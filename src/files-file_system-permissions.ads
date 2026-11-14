--  Permissions and ownership: reading and changing an entry's mode or
--  access record and its owner and group, and the account names behind
--  them. Clients with this, not the whole of Files.File_System.
package Files.File_System.Permissions is

   --  Return whether this build can read and change POSIX permission bits.
   --
   --  @return True on the Linux platform, False on the stub platforms.
   function Supports_Permissions return Boolean;

   --  Return the POSIX permission bits of Path (the low 12 mode bits).
   --
   --  @param Path Existing filesystem path to inspect.
   --  @param Available Set True when the permission bits were obtained.
   --  @return Permission bits in 0 .. 8#7777#, or 0 when Available is False.
   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural;

   --  Change the POSIX permission bits of an existing entry through chmod(2).
   --
   --  The path must already exist. Mode carries the numeric POSIX permission
   --  bits (the low 12 bits). Failures map to error.permissions.failed, and an
   --  unsupported platform maps to error.permissions.unsupported.
   --
   --  Exact, not an edit: on Windows the entry's access becomes just the
   --  three accounts' bits (Hostkit.Metadata.Set_Exact_Permissions), so 0
   --  takes access away even from an administrator -- what a test's fixture
   --  needs. A user's edit goes through Change_Access, which changes only
   --  what the bits do.
   --
   --  @param Path Existing filesystem path whose mode is changed.
   --  @param Mode New permission bits to apply.
   --  @return Mutation result with a localized error key on failure.
   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result;

   --  Return whether this build can read and change file ownership.
   --
   --  @return True on the Linux platform, False on the stub platforms.
   function Supports_Ownership return Boolean;

   --  Change the permission bits of one verified entry as a user's edit does, reporting its whole
   --  access record too where the mode cannot hold it all: on Windows the
   --  DACL, before and after (Hostkit.Metadata.Update_Entry_Metadata), which
   --  the edit changes only where the bits do. With Access_Text -- a record
   --  reported earlier -- that record is put back exactly instead of Mode:
   --  how an undo restores the access an edit changed. The records are empty
   --  on a POSIX host, where the mode is the whole of it and Access_Text is
   --  ignored.
   --
   --  @param Path Existing entry; symbolic links must be resolved by the caller.
   --  @param Expected_Identity History identity to verify, or empty for a new live change.
   --  @param Mode New permission bits, 0 .. 8#7777#.
   --  @param Access_Text An access record to restore instead of Mode, or "".
   --  @param Previous Live previous permission bits captured before mutation.
   --  @param Previous_Access The access record before the change, or "".
   --  @param Applied_Access The access record after it, or "".
   --  @param Identity Identity of the entry actually changed.
   --  @return Result of applying the change to the verified entry.
   function Change_Access
     (Path, Expected_Identity : String; Mode : Natural; Access_Text : String;
      Previous : out Natural; Previous_Access, Applied_Access, Identity : out Files.Types.UString)
      return Mutation_Result;

   --  Change the owner and group of one verified entry through a handle that
   --  pins it, capturing the ids it had.
   --
   --  @param Path Existing entry; symbolic links must be resolved by the caller.
   --  @param Expected_Identity History identity to verify, or empty for a new live change.
   --  @param User_Id New owning user id.
   --  @param Group_Id New owning group id.
   --  @param Previous_User Live previous user id captured before mutation.
   --  @param Previous_Group Live previous group id captured before mutation.
   --  @param Identity Identity of the entry actually changed.
   --  @param Owner_Name Native account name paired with User_Id when required.
   --  @param Group_Name Native account name paired with Group_Id when required.
   --  @return Result of applying the ownership to the verified entry.
   function Change_Ownership
     (Path, Expected_Identity : String; User_Id, Group_Id : Files.Types.Account_Id;
      Previous_User, Previous_Group : out Files.Types.Account_Id; Identity : out Files.Types.UString;
      Owner_Name : String := ""; Group_Name : String := "") return Mutation_Result;

   --  Resolve a user name to its numeric id (getpwnam).
   --
   --  @param Name User name to resolve.
   --  @param Found Set True when the name resolved to an id.
   --  @return The user id when Found, otherwise 0.
   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id;

   --  Resolve a group name to its numeric id (getgrnam).
   --
   --  @param Name Group name to resolve.
   --  @param Found Set True when the name resolved to an id.
   --  @return The group id when Found, otherwise 0.
   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id;

   --  Resolve a numeric user id to its name (getpwuid), memoized for the session.
   --
   --  @param Id User id to resolve.
   --  @return The user name, or the empty string when it cannot be resolved.
   function User_Name_For_Id (Id : Files.Types.Account_Id) return String;

   --  Resolve a numeric group id to its name (getgrgid), memoized for the session.
   --
   --  @param Id Group id to resolve.
   --  @return The group name, or the empty string when it cannot be resolved.
   function Group_Name_For_Id (Id : Files.Types.Account_Id) return String;

end Files.File_System.Permissions;
