package body Files.Platform.Metadata is

   function File_Creation_Time
     (Path      : String;
      Available : out Boolean)
      return Ada.Calendar.Time
   is
      pragma Unreferenced (Path);
   begin
      Available := False;
      return Ada.Calendar.Time_Of (1901, 1, 1);
   end File_Creation_Time;

   function Symlink_Target_Token (Path : String) return String is
      pragma Unreferenced (Path);
   begin
      return "";
   end Symlink_Target_Token;

   function Volume_Capacity_Of (Path : String) return Volume_Capacity is
      pragma Unreferenced (Path);
   begin
      return (others => <>);
   end Volume_Capacity_Of;

   function Create_Symbolic_Link
     (Target    : String;
      Link_Path : String)
      return Boolean
   is
      pragma Unreferenced (Target, Link_Path);
   begin
      return False;
   end Create_Symbolic_Link;

   function Create_Hard_Link
     (Existing_Path : String;
      New_Path      : String)
      return Boolean
   is
      pragma Unreferenced (Existing_Path, New_Path);
   begin
      return False;
   end Create_Hard_Link;

   function File_Permission_Bits
     (Path      : String;
      Available : out Boolean)
      return Natural
   is
      pragma Unreferenced (Path);
   begin
      Available := False;
      return 0;
   end File_Permission_Bits;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Boolean
   is
      pragma Unreferenced (Path, Mode);
   begin
      return False;
   end Set_Permissions;

   function Permissions_Supported return Boolean is
   begin
      return False;
   end Permissions_Supported;

   procedure File_Ownership
     (Path      : String;
      User_Id   : out Natural;
      Group_Id  : out Natural;
      Available : out Boolean)
   is
      pragma Unreferenced (Path);
   begin
      User_Id := 0;
      Group_Id := 0;
      Available := False;
   end File_Ownership;

   function Set_Ownership
     (Path     : String;
      User_Id  : Natural;
      Group_Id : Natural)
      return Boolean
   is
      pragma Unreferenced (Path, User_Id, Group_Id);
   begin
      return False;
   end Set_Ownership;

   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural
   is
      pragma Unreferenced (Name);
   begin
      Found := False;
      return 0;
   end User_Id_For_Name;

   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural
   is
      pragma Unreferenced (Name);
   begin
      Found := False;
      return 0;
   end Group_Id_For_Name;

   function User_Name_For_Id (Id : Natural) return String is
      pragma Unreferenced (Id);
   begin
      return "";
   end User_Name_For_Id;

   function Group_Name_For_Id (Id : Natural) return String is
      pragma Unreferenced (Id);
   begin
      return "";
   end Group_Name_For_Id;

   function Ownership_Supported return Boolean is
   begin
      return False;
   end Ownership_Supported;

end Files.Platform.Metadata;
