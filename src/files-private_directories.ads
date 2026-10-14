--  Native owner-only directory creation shared by transports and staging.
with GNAT.OS_Lib;

package Files.Private_Directories is
   type Create_Result is (Created, Collision);

   --  Try to create Path atomically with owner-only access. A pre-existing
   --  pathname is reported separately from every setup failure.
   --  @param Path Candidate directory pathname.
   --  @return Created, or Collision when Path already existed.
   function Try_Create (Path : String) return Create_Result;

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
   procedure Make_File_Private (Descriptor : GNAT.OS_Lib.File_Descriptor);
end Files.Private_Directories;
