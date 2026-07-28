--  The permissions operations of Files.File_System, extracted into
--  a concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.File_System.Permissions is

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

   --  Return the numeric owner (UID) and group (GID) of Path.
   --
   --  @param Path Existing filesystem path to inspect.
   --  @param User_Id Set to the owning user id when Available is True.
   --  @param Group_Id Set to the owning group id when Available is True.
   --  @param Available Set True when the ownership ids were obtained.
   procedure Ownership_Of
     (Path      : String;
      User_Id   : out Natural;
      Group_Id  : out Natural;
      Available : out Boolean);

   --  Change the owner and group of an existing entry through chown(2).
   --
   --  The path must already exist. Because changing ownership usually requires
   --  root privileges, an unprivileged failure maps to error.ownership.denied,
   --  and an unsupported platform maps to error.ownership.unsupported.
   --
   --  @param Path Existing filesystem path whose ownership is changed.
   --  @param User_Id New owning user id to apply.
   --  @param Group_Id New owning group id to apply.
   --  @return Mutation result with a localized error key on failure.
   function Set_Ownership
     (Path     : String;
      User_Id  : Natural;
      Group_Id : Natural)
      return Mutation_Result;

   --  Resolve a user name to its numeric id (getpwnam).
   --
   --  @param Name User name to resolve.
   --  @param Found Set True when the name resolved to an id.
   --  @return The user id when Found, otherwise 0.
   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural;

   --  Resolve a group name to its numeric id (getgrnam).
   --
   --  @param Name Group name to resolve.
   --  @param Found Set True when the name resolved to an id.
   --  @return The group id when Found, otherwise 0.
   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural;

   --  Resolve a numeric user id to its name (getpwuid), memoized for the session.
   --
   --  @param Id User id to resolve.
   --  @return The user name, or the empty string when it cannot be resolved.
   function User_Name_For_Id (Id : Natural) return String;

   --  Resolve a numeric group id to its name (getgrgid), memoized for the session.
   --
   --  @param Id Group id to resolve.
   --  @return The group name, or the empty string when it cannot be resolved.
   function Group_Name_For_Id (Id : Natural) return String;

end Files.File_System.Permissions;
