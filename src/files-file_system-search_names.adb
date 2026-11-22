with Files.Text_Case;

separate (Files.File_System)
function Search_Names
  (Root_Path : String;
   Query     : String;
   Classes   : Files.File_Types.Classification;
   Options   : Files.Types.Listing_Options;
   Max_Items : Natural := Max_Search_Results)
   return Recursive_Search_Result
is
   Normalized_Query : constant String := Files.Text_Case.Fold_Case (Query);

   function Matches (Name : String) return Boolean is
   begin
      return Normalized_Query = ""
        or else Ada.Strings.Fixed.Index (Files.Text_Case.Fold_Case (Name), Normalized_Query) > 0;
   end Matches;

   --  Only names that match are built into full items: the name match is
   --  far cheaper per entry than building one.
   function Wanted (Name : String; Kind : Files.Types.Item_Kind) return Boolean is
      pragma Unreferenced (Kind);
   begin
      return Matches (Name);
   end Wanted;

   function Judge (Item : Directory_Item) return Search_Verdict is
   begin
      return (if Matches (To_String (Item.Name)) then Found else Passed);
   end Judge;
begin
   return Search_Tree (Root_Path, Classes, Options, Wanted'Access, Judge'Access, Max_Items);
end Search_Names;
