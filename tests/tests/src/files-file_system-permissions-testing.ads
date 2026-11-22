--  Test-only access to Files.File_System.Permissions' private part: the
--  hook that watches which ownership changes are asked of the host.
package Files.File_System.Permissions.Testing is

   --  From now on, count every ownership change asked of Change_Ownership
   --  (from zero), and keep the ids the last one asked for.
   procedure Watch_Ownership_Changes;

   --  Count ownership changes no more.
   procedure Stop_Watching_Ownership_Changes;

   --  @return The ownership changes asked for since Watch_Ownership_Changes.
   function Ownership_Changes return Natural;

   --  @return The user id the last ownership change asked for.
   function Last_Ownership_User return Files.Types.Account_Id;

   --  @return The group id the last ownership change asked for.
   function Last_Ownership_Group return Files.Types.Account_Id;

   --  Set Path's permission bits to exactly Mode -- a fixture's access, not a
   --  user's edit (that is Change_Access).
   --
   --  @param Path Existing filesystem path whose mode is changed.
   --  @param Mode New permission bits to apply.
   --  @return Mutation result with a localized error key on failure.
   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result;

end Files.File_System.Permissions.Testing;
