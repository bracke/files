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

end Files.Platform.Metadata;
