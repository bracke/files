--  Native owner-only directory creation shared by transports and staging.
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
end Files.Private_Directories;
