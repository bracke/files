with Files.Quick_Look;
separate (Files.File_System)
function Search_Contents
  (Root_Path : String;
   Query     : String;
   Settings  : Files.Settings.Settings_Model)
   return Recursive_Search_Result
is
   Max_Bytes  : constant := 64 * 1024;
   Max_Files  : constant := 20_000;
   Files_Read : Natural := 0;

   --  Only what is read is built into an item (folders always are).
   function Wanted (Name : String; Kind : Files.Types.Item_Kind) return Boolean is
      pragma Unreferenced (Name);
   begin
      return Kind in Files.Types.Regular_File_Item | Files.Types.Executable_Item;
   end Wanted;

   function Judge (Item : Directory_Item) return Search_Verdict is
   begin
      if Item.Kind not in Files.Types.Regular_File_Item | Files.Types.Executable_Item then
         return Passed;
      elsif Files_Read >= Max_Files then
         return Exhausted;
      end if;
      Files_Read := Files_Read + 1;
      declare
         Read_Ok : Boolean;
         Bytes   : constant String := Read_Preview_Text (To_String (Item.Full_Path), Max_Bytes + 1, Read_Ok);
         --  What is searched ends on a whole character: a cut one would
         --  leave text that is not UTF-8, and lose its folding.
         Searched : constant String :=
           (if Bytes'Length > Max_Bytes
            then Files.Types.Trim_To_Character (Bytes (Bytes'First .. Bytes'First - 1 + Max_Bytes))
            else Bytes);
      begin
         if not Read_Ok then
            return Undecided;
         elsif Content_Matches (Searched, Query) then
            return Found;
         elsif Bytes'Length > Max_Bytes and then not Files.Quick_Look.Looks_Binary (Bytes) then
            --  A text file longer than is read and no match in what was:
            --  its match could lie past it.
            return Undecided;
         end if;
         return Passed;
      end;
   end Judge;
begin
   return Search_Tree (Root_Path, Settings, Wanted'Access, Judge'Access, Max_Search_Results);
end Search_Contents;
