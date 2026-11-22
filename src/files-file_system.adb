with Ada.Calendar;
with Files.IO.Fs_Primitives;
with Files.Jobs.Context;
with Files.Jobs.Storage;
with Guikit.Shared_Bytes;
with Files.Diagnostics;
with Ada.Directories;
with Ada.Strings.Unbounded;

with System;

with GNAT.OS_Lib;

with Files.Item_Lists;

with Hostkit.Metadata;
with Hostkit.Filesystem_Rules;
with Hostkit.Fs;
with Hostkit.Path_Text;
with Hostkit.Host;
with Hostkit.Regular_Files;
with Guikit.Utf8.Editing;
with Files.Leaf_Names;
with Files.File_System.Content_Info;
with Files.File_System.Support;
with Files.File_System.Thumbnails;
with Files.File_System.Recovery;
with Files.File_System.Trash;
with Files.File_Identities;
with Files.IO.Errors;
with Hostkit.Trash;
with Files.Name_Parts;
with Files.Text_Case;

package body Files.File_System is

   --  Short for the subunits: the one public name is Fs_Primitives'.
   function Parent_Directory (Path : String) return String renames Files.IO.Fs_Primitives.Parent_Directory;
   use type Hostkit.Host.Kind;

   use Files.File_System.Thumbnails;
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;

   use type System.Address;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Files.Types.Item_Kind;

   function Read_Bounded_Regular_File
     (Path : String; Max_Bytes : Natural;
      Success, Complete : out Boolean) return String
   is separate;

   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String
   is
      Success : Boolean;
   begin
      return Read_Preview_Text (Path, Max_Bytes, Success);
   end Read_Preview_Text;

   function Read_Preview_Text
     (Path : String; Max_Bytes : Natural; Success : out Boolean) return String
   is
      Complete : Boolean;
      Result   : constant String := Read_Preview_Text (Path, Max_Bytes, Success, Complete);

      procedure Ignore_Completion (Value : Boolean) is
         pragma Unreferenced (Value);
      begin
         null;
      end Ignore_Completion;
   begin
      --  These callers accept a leading prefix as it is.
      Ignore_Completion (Complete);
      return Result;
   end Read_Preview_Text;

   function Read_Preview_Text
     (Path : String; Max_Bytes : Natural; Success, Complete : out Boolean) return String
   is separate;

   --  @param Path The item's full path.
   --  @param Kind How the item was already classified, which for most kinds
   --              settles executability without asking the host again.
   --  @param Mode_Bits POSIX mode already read for this item, when Mode_Known.
   --  @param Mode_Known True when Mode_Bits are the host's own bits.
   function Permission_String
     (Path       : String;
      Kind       : Files.Types.Item_Kind;
      Mode_Bits  : Natural;
      Mode_Known : Boolean)
      return String;

   function Kind_From_Path
     (Full : String)
      return Files.Types.Item_Kind;

   function Entry_Is_Hidden (Name : String; Full : String) return Boolean is
      Dotted : constant Boolean := Name'Length > 0 and then Name (Name'First) = '.';
   begin
      return Dotted or else Hostkit.Fs.Is_Hidden (Full);
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.File_System");
         return Dotted;
   end Entry_Is_Hidden;

   --  @param Hidden Whether the entry is hidden (Entry_Is_Hidden), which a
   --  listing has already asked before it builds the item.
   function Item_For_Path
     (Full        : String;
      Name        : String;
      Parent_Path : String;
      Kind        : Files.Types.Item_Kind;
      Classes     : Files.File_Types.Classification;
      Cached      : Cache_Index;
      Hidden      : Boolean)
      return Directory_Item;

   function Permission_String
     (Path       : String;
      Kind       : Files.Types.Item_Kind;
      Mode_Bits  : Natural;
      Mode_Known : Boolean)
      return String
   is separate;

   function Extra_Info_Of
     (Path        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String;
      Show_Hidden : Boolean := True)
      return Files.Extra_Info.Info renames Content_Info.Extra_Info_Of;

   function Kind_From_Path
     (Full : String)
      return Files.Types.Item_Kind
   is separate;

   function Item_For_Path
     (Full        : String;
      Name        : String;
      Parent_Path : String;
      Kind        : Files.Types.Item_Kind;
      Classes     : Files.File_Types.Classification;
      Cached      : Cache_Index;
      Hidden      : Boolean)
      return Directory_Item
   is separate;

   --  Count the entry Name of the directory Result.Path into Result, as
   --  Directory_State does for each entry it reads.
   procedure Add_To_Signature
     (Result : in out Directory_Signature;
      Name   : String)
   is separate;

   function Load_Directory_Filtered
     (Path     : String;
      Classes  : Files.File_Types.Classification;
      Options  : Files.Types.Listing_Options;
      Include  : access function
        (Name : String; Kind : Files.Types.Item_Kind) return Boolean;
      Generate_Thumbnails : Boolean := False;
      With_Signature      : Boolean := False)
      return Directory_Load_Result
   is separate;

   function Load_Directory
     (Path    : String;
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options)
      return Directory_Load_Result is separate;

   function Load_Directory_Deferring_Thumbnails
     (Path    : String;
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options)
      return Directory_Load_Result is separate;

   function Load_Directory_Generating_Thumbnails
     (Path    : String;
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options)
      return Directory_Load_Result is separate;

   function Load_Subdirectories
     (Path     : String;
      Classes  : Files.File_Types.Classification;
      Options  : Files.Types.Listing_Options)
      return Directory_Load_Result is separate;

   function Thumbnails_Missing (Items : Item_Vectors.Vector) return Boolean is separate;

   function Load_Item
     (Full_Path : String;
      Classes   : Files.File_Types.Classification)
      return Item_Load_Result
   is separate;

   function Directory_State
     (Path : String)
      return Directory_Signature
   is separate;

   function Detect_Directory_Change
     (Before_State : Directory_Signature;
      Path         : String)
      return Directory_Change_Result
   is separate;

   function Directory_Size
     (Path        : String;
      Max_Entries : Natural := 50_000;
      Max_Depth   : Natural := 64)
      return Directory_Size_Result
   is separate;

   --  Remove Path only while it is still the entry Expected_Identity names
   --  (and, with Verify_Tree, still holds what Expected_Tree_Revision says).
   function Delete_Verified_Entry
     (Path : String;
      Expected_Identity, Expected_Tree_Revision : String;
      Verify_Tree : Boolean) return Mutation_Result;

   function Path_Is_Within_By
     (Child, Parent : String;
      Folds         : not null access function (Directory : String) return Boolean)
      return Boolean
   is
      --  How many names deep Path is: its root none.
      function Depth (Path : String) return Natural is
         Count : Natural := 0;
         Walk  : Unbounded_String := To_Unbounded_String (Path);
      begin
         while Parent_Directory (To_String (Walk)) not in "" | "." loop
            Count := Count + 1;
            Walk := To_Unbounded_String (Parent_Directory (To_String (Walk)));
         end loop;
         return Count;
      end Depth;

      --  Whether Left (of Child) and Right (of Parent), as deep as each
      --  other, are one entry: each name compared by the rule of the folder
      --  it is in -- exactly, unless that folder's volume folds names -- so
      --  the folders above a mount compare exactly, and only from the mount
      --  point down are names folded. A stick mounted at /media/u/STICK
      --  folds the names inside it, but /media/u/stick is another folder of
      --  /media/u. A root folds when its own volume does.
      function Same_Entry (Left, Right : String) return Boolean is
         Holder : constant String := Parent_Directory (Right);
      begin
         if Left = Right then
            return True;
         elsif Files.Text_Case.Fold_Case (Left) /= Files.Text_Case.Fold_Case (Right) then
            return False;
         elsif Holder in "" | "." then
            return Folds (Right);
         elsif Files.Name_Parts.Leaf_Of (Left) /= Files.Name_Parts.Leaf_Of (Right)
           and then not Folds (Holder)
         then
            return False;
         end if;
         return Same_Entry (Parent_Directory (Left), Holder);
      end Same_Entry;

      --  Path without the separators it may end in, a root's own kept.
      function Trimmed (Path : String) return String is
         Last : Natural := Path'Last;
      begin
         while Last - Path'First + 1 > Hostkit.Path_Text.Root_Length (Path)
           and then Hostkit.Fs.Is_Separator (Path (Last))
         loop
            Last := Last - 1;
         end loop;
         return Path (Path'First .. Last);
      end Trimmed;
   begin
      if Hostkit.Fs.Is_Same_Or_Inside (Child, Parent) then
         return True;
      elsif not Hostkit.Fs.Is_Same_Or_Inside
          (Files.Text_Case.Fold_Case (Child), Files.Text_Case.Fold_Case (Parent))
      then
         return False;
      end if;
      --  Within by folding alone: Child's folder as deep as Parent must be
      --  Parent, each of its names by its own folder's rule.
      declare
         Top          : constant String := Trimmed (Parent);
         Parent_Depth : constant Natural := Depth (Top);
         Head         : Unbounded_String := To_Unbounded_String (Trimmed (Child));
      begin
         for Extra in 1 .. Depth (To_String (Head)) - Natural'Min (Parent_Depth, Depth (To_String (Head))) loop
            Head := To_Unbounded_String (Parent_Directory (To_String (Head)));
         end loop;
         return Same_Entry (To_String (Head), Top);
      end;
   end Path_Is_Within_By;

   function Path_Is_Within (Child, Parent : String) return Boolean is
     (Path_Is_Within_By (Child, Parent, Hostkit.Fs.Folds_Name_Case'Access));

   function Expand_User_Path (Path : String) return String is separate;

   function Normalize_Path
     (Path : String)
      return Path_Result
   is separate;

   function Is_All_Whitespace (Name : String) return Boolean is separate;

   function Ends_With_Whitespace (Name : String) return Boolean is separate;

   function Valid_Leaf_Name
     (Name  : String;
      Rules : Name_Rules := Host_Rules)
      return Boolean
   is separate;

   function Valid_Leaf_Name_At
     (Name      : String;
      Directory : String)
      return Boolean
   is
     (Valid_Leaf_Name
        (Name,
         (if Hostkit.Fs.Uses_Dos_Filename_Rules (Directory)
          then Windows_Rules
          else Posix_Rules)));

   --  Whether Name is longer than a filesystem under Directory stores
   --  (Files.Leaf_Names.Too_Long_Under for that filesystem's rules). Checked
   --  before the disk is touched, so every host reports it alike (a Windows
   --  runner was seen creating a 300-character name).
   function Leaf_Too_Long (Name : String; Directory : String) return Boolean is
     (Files.Leaf_Names.Too_Long_Under (Name, Hostkit.Fs.Leaf_Name_Limit_At (Directory)));

   function Storable_Leaf_Name_At
     (Name      : String;
      Directory : String)
      return Boolean
   is separate;

   function Next_Untitled_Name
     (Directory_Path : String)
      return String
   is separate;

   function Mutation_Leaf_Name (Path : String) return String;

   --  Whether Path can take a new entry: not empty (else Empty_Key), a leaf
   --  name the destination accepts (stores, when Storable; is valid,
   --  otherwise), nothing there yet, inside an existing directory.
   function Validate_New_Entry
     (Path      : String;
      Empty_Key : String;
      Storable  : Boolean := False)
      return Mutation_Result;

   function Validate_Link_Destination
     (Link_Path : String)
      return Mutation_Result is
     (Validate_New_Entry (Link_Path, "error.link.failed", Storable => True));

   function Mutation_Leaf_Name (Path : String) return String is separate;

   function Validate_New_Entry
     (Path      : String;
      Empty_Key : String;
      Storable  : Boolean := False)
      return Mutation_Result
   is separate;

   function Create_Empty_File
     (Path : String)
      return Mutation_Result
   is separate;

   function Create_Directory
     (Path : String)
      return Mutation_Result
   is separate;

   function Rename_Item
     (From_Path : String;
      To_Path   : String;
      Expected_Identity : String := "")
      return Mutation_Result
   is
      Left_At : UString;
      Failure : Rename_Failure;
   begin
      return Rename_Item (From_Path, To_Path, Left_At, Failure, Expected_Identity);
   end Rename_Item;

   function Rename_Item
     (From_Path : String;
      To_Path   : String;
      Left_At   : out UString;
      Failure   : out Rename_Failure;
      Expected_Identity : String := "")
      return Mutation_Result
   is separate;

   function Create_Link_Of_Kind
     (Source_Path : String;
      Link_Path   : String;
      Hard        : Boolean)
      return Mutation_Result
   is separate;

   function Create_Symbolic_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result is (Create_Link_Of_Kind (Source_Path, Link_Path, Hard => False));

   function Create_Hard_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result is (Create_Link_Of_Kind (Source_Path, Link_Path, Hard => True));

   function Delete_Permanently
     (Path : String)
      return Mutation_Result
   is separate;

   function Delete_Verified_Entry
     (Path : String;
      Expected_Identity, Expected_Tree_Revision : String;
      Verify_Tree : Boolean) return Mutation_Result
   is separate;

   function Delete_Created_Entry
     (Path : String; Expected_Identity, Expected_Tree_Revision : String) return Mutation_Result is
   begin
      return Delete_Verified_Entry
        (Path, Expected_Identity, Expected_Tree_Revision, Verify_Tree => True);
   end Delete_Created_Entry;

   function Delete_Staging_Entry
     (Path : String; Expected_Identity : String) return Mutation_Result is
   begin
      return Delete_Verified_Entry
        (Path, Expected_Identity, "", Verify_Tree => False);
   end Delete_Staging_Entry;

   function Delete_Transport_Entry
     (Path : String; Expected_Identity : String) return Mutation_Result
   is separate;

   function Tree_Revision (Path : String) return String is
   begin
      return Support.Tree_Revision (Path);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return "";
   end Tree_Revision;

   function Entry_Identity_Matches (Path, Expected : String) return Boolean is
   begin
      --  refusal-safe: what cannot be looked at is unverified, and an
      --  unverified entry is never acted on (not undone, not removed).
      return Expected /= ""
        --  refusal-safe: as above.
        and then Files.IO.Fs_Primitives.Entry_Exists (Path)
        and then Files.File_Identities.Token (Path) = Expected;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return False;
   end Entry_Identity_Matches;

   function Creation_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean := False) return Boolean is
      Refuse : constant Restore_Hook := Refuse_Creation_Match;
   begin
      if Refuse /= null and then Refuse (Path) then
         return False;
      end if;
      if not Entry_Identity_Matches (Path, Identity) then
         return Retain_Verified and then Identity /= "";
      end if;
      return
        (if Hostkit.Fs.Is_Link (Path) then Tree_Revision = ""
         else Tree_Revision /= "" and then Files.File_System.Tree_Revision (Path) = Tree_Revision);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return False;
   end Creation_Matches;

   function Job_Cancelled return Cancellation_Check is (Files.Jobs.Context.Cancelled'Access);

   --  Files.Jobs.Storage's operations: the job layer's view of the removals
   --  and the creation check above, which it reaches without naming this
   --  package.
   function Remove_Stage_For_Jobs (Path, Expected_Identity : String) return Boolean is
     (Delete_Staging_Entry (Path, Expected_Identity).Success);

   function Remove_Transport_For_Jobs (Path, Expected_Identity : String) return Boolean is
     (Delete_Transport_Entry (Path, Expected_Identity).Success);

   function Creation_Matches_For_Jobs
     (Path, Identity, Tree_Revision : String; Retain_Verified : Boolean) return Boolean is
     (Creation_Matches (Path, Identity, Tree_Revision, Retain_Verified));

begin
   Files.Jobs.Storage.Install
     (Delete_Staging   => Remove_Stage_For_Jobs'Access,
      Delete_Transport => Remove_Transport_For_Jobs'Access,
      Matches          => Creation_Matches_For_Jobs'Access,
      Revision         => Tree_Revision'Access);
end Files.File_System;
