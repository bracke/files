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

end Files.Platform.Metadata;
