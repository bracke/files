package body Files.File_System.Permissions.Testing is

   --  What Watch_Ownership_Changes has seen.
   Ownership_Change_Count : Natural := 0;
   Last_User, Last_Group  : Files.Types.Account_Id := 0;

   --  The Before_Ownership_Change hook Watch_Ownership_Changes installs.
   procedure Note_Ownership_Change (Path : String; User_Id, Group_Id : Files.Types.Account_Id) is
      pragma Unreferenced (Path);
   begin
      Ownership_Change_Count := Ownership_Change_Count + 1;
      Last_User := User_Id;
      Last_Group := Group_Id;
   end Note_Ownership_Change;

   procedure Watch_Ownership_Changes is
   begin
      Ownership_Change_Count := 0;
      Last_User := 0;
      Last_Group := 0;
      Before_Ownership_Change := Note_Ownership_Change'Access;
   end Watch_Ownership_Changes;

   procedure Stop_Watching_Ownership_Changes is
   begin
      Before_Ownership_Change := null;
   end Stop_Watching_Ownership_Changes;

   function Ownership_Changes return Natural is (Ownership_Change_Count);

   function Last_Ownership_User return Files.Types.Account_Id is (Last_User);

   function Last_Ownership_Group return Files.Types.Account_Id is (Last_Group);

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result renames Files.File_System.Permissions.Set_Permissions;

end Files.File_System.Permissions.Testing;
