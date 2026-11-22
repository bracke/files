--  Native owner-only directory creation shared by transports and staging.
with GNAT.OS_Lib;

package Files.IO.Private_Directories is
   type Create_Result is (Created, Collision);

   --  Try to create Path atomically with owner-only access. A pre-existing
   --  pathname is reported separately from every setup failure.
   --  @param Path Candidate directory pathname.
   --  @return Created, or Collision when Path already existed.
   function Try_Create (Path : String) return Create_Result;

   --  Create the first free numbered directory Prefix & "1" .. Prefix &
   --  "9999" under Parent, atomically and owner-only, so a bounded set of
   --  names serves staging and recovery slots.
   --  @param Parent Directory the slot is made in.
   --  @param Prefix The slot name's text before its number.
   --  @param Reclaim Asked about a name already taken: True when it removed
   --    a stale slot there, so the create is tried once more; null keeps
   --    every taken name.
   --  @return The created directory, or "" when every name is taken.
   function Create_Numbered
     (Parent  : String;
      Prefix  : String;
      Reclaim : access function (Path : String) return Boolean := null)
      return String;

   --  Create Path atomically with owner-only access and without an inherited
   --  default ACL. Raises Use_Error on failure or collision.
   --  @param Path Unused directory pathname to create.
   procedure Create (Path : String);

   --  Create Path when absent, or verify and harden an existing directory.
   --  Symbolic links and directories not owned by the current account fail.
   --  @param Path Directory that must be private before it is used.
   procedure Ensure (Path : String);

   --  Restrict an open, newly-created regular file to its owner. This also
   --  removes any access ACL inherited at creation time.
   --  @param Descriptor Open descriptor for the new file.
   --  @raise Ada.Directories.Use_Error when the host refuses, its reason
   --    (zero when it gave none) the code recorded with Files.IO.Errors.
   procedure Make_File_Private (Descriptor : GNAT.OS_Lib.File_Descriptor);
end Files.IO.Private_Directories;
