with Files.Text_Encoding;
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
   --  Folded once for the whole search.
   Folded_Query : constant String := Files.Types.Fold_Case (Query);

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
         --  What is searched: the first Max_Bytes, as text (Searchable_Text
         --  drops a character the cut split).
         Searched : constant String :=
           (if Bytes'Length > Max_Bytes then Bytes (Bytes'First .. Bytes'First - 1 + Max_Bytes) else Bytes);
         --  Decoded once, for the match and for whether it is text.
         Text     : constant String := (if Read_Ok then Files.Text_Encoding.Searchable_Text (Searched) else "");
      begin
         if not Read_Ok then
            return Undecided;
         elsif Files.Types.Text_Contains (Text, Folded_Query) then
            return Found;
         elsif Bytes'Length > Max_Bytes and then not Files.Text_Encoding.Looks_Binary (Text) then
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
