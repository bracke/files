with Files.IO.Fs_Primitives;
with Files.Jobs.Context;
with Files.Diagnostics;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.IO.Errors;
with Files.Text_Case;

package body Files.File_System.Search is

   use Ada.Strings.Unbounded;
   use type Files.Types.Item_Kind;

   --  What a search makes of one listed item: a match, no match, one it
   --  could not search (the answer is Incomplete), or a limit reached (the
   --  walk ends, Truncated).
   type Search_Verdict is (Found, Passed, Undecided, Exhausted);

   --  The one bounded walk behind both searches: from Root_Path down real
   --  folders only (a linked folder is an item, so cycles are impossible),
   --  at most Max_Search_Depth deep and 100,000 listed entries, cancellable.
   --  Every listed entry Wanted keeps is built into an item and judged by
   --  Judge; folders are descended into whether wanted or not. A folder
   --  below the root that cannot be read is skipped (Incomplete); a limit
   --  reached ends the walk (Truncated). Only an unreadable root fails.
   --
   --  @param Root_Path Directory where the walk starts.
   --  @param Classes Filetype and icon maps items are classified by.
   --  @param Options Hidden-entry and sort policy.
   --  @param Wanted Which listed entries to build into items, besides folders.
   --  @param Judge The search's verdict on one built item.
   --  @param Max_Items How many matches to keep.
   --  @return The matches in walk order, and whether the walk was cut short.
   function Search_Tree
     (Root_Path : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options;
      Wanted    : not null access function (Name : String; Kind : Files.Types.Item_Kind) return Boolean;
      Judge     : not null access function (Item : Directory_Item) return Search_Verdict;
      Max_Items : Natural)
      return Recursive_Search_Result is separate;

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean is separate;

   function Search_Contents
     (Root_Path : String;
      Query     : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options)
      return Recursive_Search_Result is separate;

   function Search_Names
     (Root_Path : String;
      Query     : String;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options;
      Max_Items : Natural := Max_Search_Results)
      return Recursive_Search_Result
   is separate;

   function Search_Folder
     (Root_Path : String;
      Query     : String;
      Scope     : Files.UI_Types.Tree_Search_Scope;
      Classes   : Files.File_Types.Classification;
      Options   : Files.Types.Listing_Options)
      return Folder_Search_Result
   is
      use type Files.UI_Types.Search_Scope;
      Found : constant Recursive_Search_Result :=
        (if Scope = Files.UI_Types.Search_Contents
         then Search_Contents (Root_Path, Query, Classes, Options)
         else Search_Names (Root_Path, Query, Classes, Options));
   begin
      if not Found.Success then
         return (Success => False, Error_Key => Found.Error_Key, others => <>);
      end if;
      return
        (Success   => True,
         Items     => Found.Items,
         Error_Key => Null_Unbounded_String,
         Notice    => To_Unbounded_String (Notice_Of (Found)),
         Signature => Directory_State (Root_Path));
   end Search_Folder;

end Files.File_System.Search;
