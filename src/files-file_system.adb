with Files.Fs_Primitives;
with Files.Jobs.Context;
with Files.Jobs.Storage;
with Ada.Streams;
with Guikit.Shared_Bytes;
with Files.Environment;
with Files.Diagnostics;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with System;

with GNAT.OS_Lib;

with Files.File_Types;
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
with Files.File_Identities;
with Files.File_System.Account_Names;
with Files.Private_Directories;
with Files.Io_Errors;
with Hostkit.Trash;
with Files.Bounded_Text_IO;

package body Files.File_System is

   --  Short for the subunits: the one public name is Fs_Primitives'.
   function Parent_Directory (Path : String) return String renames Files.Fs_Primitives.Parent_Directory;
   use type Hostkit.Host.Kind;

   use Files.File_System.Support;
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
      Settings    : Files.Settings.Settings_Model;
      Cached      : Cache_Index;
      Hidden      : Boolean)
      return Directory_Item;

   procedure Sort_Items
     (Items     : in out Item_Vectors.Vector;
      Field     : Files.Types.Sort_Field;
      Ascending : Boolean)
     renames Files.Item_Lists.Sort_Items;

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
      Settings    : Files.Settings.Settings_Model;
      Cached      : Cache_Index;
      Hidden      : Boolean)
      return Directory_Item
   is separate;

   --  The freedesktop trash per volume: an item on another device than the
   --  home trash goes to its volume's own trash ($topdir/.Trash/$uid when the
   --  administrator made a sticky .Trash there, else $topdir/.Trash-$uid), a
   --  rename instead of a copy into home. The trash view lists them all.

   --  Whether volume trashes are used: the freedesktop backends, on a host
   --  with numeric user ids.
   function Volume_Trash_Supported return Boolean;

   --  How many volume trashes the list of those trashed into keeps.
   Max_Remembered_Volume_Trashes : constant := 64;

   --  The volume trashes this application has trashed into, oldest first, as
   --  Volume_Trash_For recorded them (unvalidated). Complete is False when a
   --  list is there (or may be) but could not be read whole: what is
   --  returned then is no basis for writing the list again.
   function Remembered_Volume_Trashes (Complete : out Boolean) return Files.Types.String_Vectors.Vector;

   --  Whether Base is one of this user's volume trash directories: named
   --  .Trash-$uid, or $uid inside a sticky .Trash, a real directory (not a
   --  link) owned by this user.
   function Valid_Volume_Trash_Base (Base : String) return Boolean;

   --  Whether Parent may hold this user's volume trash: for the shared
   --  .Trash (Shared), a real directory owned by root with the sticky bit,
   --  so no one else can swap our folder in it for a link; for the volume's
   --  top, a real directory only its owner can write to, unless sticky. An
   --  Existing trash (one being listed or restored from, not made) may also
   --  sit under a top its group can write to.
   function Safe_Trash_Parent (Parent : String; Shared : Boolean; Existing : Boolean := False) return Boolean;

   --  The one rule every "is this path inside that one" check here follows:
   --  Hostkit.Fs.Is_Same_Or_Inside on the text (a root such as "/" or "C:\"
   --  holds every longer path; /a/bc is not inside /a/b), and on the
   --  case-folded text too where each of Parent's names may be folded: a
   --  name compares by the rule of the folder it is in (Hostkit.Fs.
   --  Folds_Name_Case of that folder, or of a root itself), since where
   --  that folds C:\Data and c:\data are one folder. So the folders above
   --  a mount compare exactly and only from the mount point down are names
   --  folded: a case-folding stick mounted at /media/u/STICK does not make
   --  /media/u/stick the same folder, as /media/u, where both names are,
   --  tells them apart, nor /MEDIA/u/STICK, as / does. Below Parent the
   --  spelling does not matter: Child is inside once its head is Parent.
   --  The volume is asked only when the spellings differ by case alone, so
   --  an exact match never waits on a slow mount. Making the paths absolute
   --  or resolving links is the caller's choice.
   --  @param Child Candidate path.
   --  @param Parent Candidate ancestor.
   --  @return True when Child is Parent or lies inside it.
   function Path_Is_Within (Child, Parent : String) return Boolean;

   --  Path below Top, relative to it ("" when Path is not under Top, by
   --  Path_Is_Within). Top may be "/" (or end in a separator): the tail
   --  starts after the separator that ends Top's spelling in Path.
   function Relative_To_Top (Path, Top : String) return String;

   --  The top of the volume a volume trash Base belongs to: the parent of
   --  .Trash-$uid, or of .Trash for .Trash/$uid.
   function Volume_Trash_Top (Base : String) return String;

   --  Whether Base is a per-user folder in a volume's .Trashes: the Finder's
   --  layout, which keeps its items in Base itself, with no info files.
   function Is_Finder_Volume_Trash (Base : String) return Boolean;

   --  The folder of a trash base that holds its items: its files/, or the
   --  base itself in the Finder's layout.
   function Trash_Items_Directory (Base : String) return String;

   --  The volume trash to move Path into, created if need be and remembered
   --  for the trash view; "" when Path is on the home trash's device or its
   --  volume has no usable trash (read-only, no permission), and the home
   --  trash is used.
   function Volume_Trash_For (Path : String) return String;

   --  Every existing volume trash of this user: on the mounts the root list
   --  shows, and those this application has trashed into.
   function Volume_Trash_Bases return Files.Types.String_Vectors.Vector;

   --  The trash directory (holding files/ and info/) whose files/ directly
   --  holds Trashed_Path: the home trash or a volume trash; "" for anything
   --  else.
   function Trash_Base_Of (Trashed_Path : String) return String;

   --  Count the entry Name of the directory Result.Path into Result, as
   --  Directory_State does for each entry it reads.
   procedure Add_To_Signature
     (Result : in out Directory_Signature;
      Name   : String)
   is separate;

   function Load_Directory_Filtered
     (Path     : String;
      Settings : Files.Settings.Settings_Model;
      Options  : Files.Types.Listing_Options;
      Include  : access function
        (Name : String; Kind : Files.Types.Item_Kind) return Boolean;
      Generate_Thumbnails : Boolean := False;
      With_Signature      : Boolean := False)
      return Directory_Load_Result
   is separate;

   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result is separate;

   function Load_Directory_Deferring_Thumbnails
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result is separate;

   function Load_Directory_Generating_Thumbnails
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result is separate;

   function Load_Subdirectories
     (Path     : String;
      Settings : Files.Settings.Settings_Model;
      Options  : Files.Types.Listing_Options)
      return Directory_Load_Result is separate;

   function Thumbnails_Missing (Items : Item_Vectors.Vector) return Boolean is separate;

   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Item_Load_Result
   is separate;

   function Load_Recent_Items (Settings : Files.Settings.Settings_Model) return Item_Vectors.Vector is separate;

   function Unknown_Signature (Path : String := "") return Directory_Signature
     renames Files.File_System_Types.Unknown_Signature;

   function Same_State (Left, Right : Directory_Signature) return Boolean is
     (Left.Taken
      and then Right.Taken
      and then Left.Path = Right.Path
      and then Left.Exists = Right.Exists
      and then Left.Entry_Count = Right.Entry_Count
      and then Left.Entry_State_Checksum = Right.Entry_State_Checksum
      and then Left.Latest_Modified_Known = Right.Latest_Modified_Known
      and then
        (not Left.Latest_Modified_Known
         or else not Right.Latest_Modified_Known
         or else Left.Latest_Modified = Right.Latest_Modified));

   function Directory_State
     (Path : String)
      return Directory_Signature
   is separate;

   function Detect_Directory_Change
     (Before_State : Directory_Signature;
      Path         : String)
      return Directory_Change_Result
   is separate;

   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String := "")
      return Directory_Item
     renames Files.Item_Lists.Make_Item;

   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
      return Directory_Item
   is
      Filetype : constant String := Files.File_Types.Detect_Filetype (Settings, Kind, Name);
   begin
      return
        (Name        => To_Unbounded_String (Name),
         Full_Path   => To_Unbounded_String (Hostkit.Fs.Join (Parent_Path, Name)),
         Parent_Path => To_Unbounded_String (Parent_Path),
         Hidden      => Entry_Is_Hidden (Name, Hostkit.Fs.Join (Parent_Path, Name)),
         Kind        => Kind,
         Filetype    => To_Unbounded_String (Filetype),
         Icon_Id     => To_Unbounded_String (Files.File_Types.Icon_Id_For (Settings, Kind, Filetype)),
         others      => <>);
   end Make_Item;

   function Directory_Size
     (Path        : String;
      Max_Entries : Natural := 50_000;
      Max_Depth   : Natural := 64)
      return Directory_Size_Result
   is separate;

   function Original_Path (Trashed_Path : String) return String;

   --  Remove Path only while it is still the entry Expected_Identity names
   --  (and, with Verify_Tree, still holds what Expected_Tree_Revision says).
   function Delete_Verified_Entry
     (Path : String;
      Expected_Identity, Expected_Tree_Revision : String;
      Verify_Tree : Boolean) return Mutation_Result;

   function Restore_From_Trash_Backend
     (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
      return Mutation_Result;

   function Delete_From_Trash_Backend
     (Trashed_Path : String)
      return Mutation_Result;

   function Trash_Base_Path return String;

   function Path_Can_Be_Directory (Path : String) return Boolean;

   function Two_Digit_Text (Value : Natural) return String;

   type Trash_Location is record
      Backend : Trash_Backend := Trash_Unavailable;
      Base    : Unbounded_String := Null_Unbounded_String;
   end record;

   function Trash_Location_For_Environment return Trash_Location is separate;

   --  The system drive's Recycle Bin folder once found (Trash_Files_Directory);
   --  empty until then, as it is before anything was ever recycled there.
   --  Protected: a listing on a background reader may ask too.
   protected Primary_Recycle_Bin is
      function Get return String;
      procedure Set (Folder : String);
   private
      Value : Unbounded_String;
   end Primary_Recycle_Bin;

   protected body Primary_Recycle_Bin is
      function Get return String is (To_String (Value));

      procedure Set (Folder : String) is
      begin
         Value := To_Unbounded_String (Folder);
      end Set;
   end Primary_Recycle_Bin;

   function Trash_Base_Path return String is separate;

   function Trash_Files_Directory return String is separate;

   function Valid_Original_Path (Path : String) return Boolean is separate;

   function Is_Trash_Payload (Path, Payload_Directory : String) return Boolean is separate;

   function Volume_Trash_Supported return Boolean is separate;

   function Remembered_Volume_Trashes (Complete : out Boolean) return Files.Types.String_Vectors.Vector
     is separate;

   function Valid_Volume_Trash_Base (Base : String) return Boolean is separate;

   function Safe_Trash_Parent (Parent : String; Shared : Boolean; Existing : Boolean := False) return Boolean
     is separate;

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
         elsif Files.Types.Fold_Case (Left) /= Files.Types.Fold_Case (Right) then
            return False;
         elsif Holder in "" | "." then
            return Folds (Right);
         elsif Files.Types.Leaf_Of (Left) /= Files.Types.Leaf_Of (Right)
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
      elsif not Hostkit.Fs.Is_Same_Or_Inside (Files.Types.Fold_Case (Child), Files.Types.Fold_Case (Parent)) then
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

   function Relative_To_Top (Path, Top : String) return String is
      Top_Ends_In_Separator : constant Boolean := Top /= "" and then Hostkit.Fs.Is_Separator (Top (Top'Last));
   begin
      if Top = "" or else not Path_Is_Within (Path, Top) then
         return "";
      end if;
      --  Top's spelling in Path ends at the separator whose head is Top, or
      --  folds to it where Path_Is_Within matched by folding.
      for Last in Path'First .. Path'Last - 1 loop
         if Hostkit.Fs.Is_Separator (Path (Last)) then
            declare
               Head : constant String :=
                 (if Top_Ends_In_Separator then Path (Path'First .. Last) else Path (Path'First .. Last - 1));
            begin
               if Head = Top or else Files.Types.Fold_Case (Head) = Files.Types.Fold_Case (Top) then
                  return Path (Last + 1 .. Path'Last);
               end if;
            end;
         end if;
      end loop;
      return "";
   end Relative_To_Top;

   function Volume_Trash_Top (Base : String) return String is
     (if Files.Types.Leaf_Of (Base) (1 .. Natural'Min (7, Files.Types.Leaf_Of (Base)'Length))
           = ".Trash-"
      then Files.Fs_Primitives.Parent_Directory (Base)
      else Files.Fs_Primitives.Parent_Directory (Files.Fs_Primitives.Parent_Directory (Base)));

   function Is_Finder_Volume_Trash (Base : String) return Boolean is
     (Base /= ""
      and then Files.Types.Leaf_Of (Files.Fs_Primitives.Parent_Directory (Base)) = ".Trashes");

   function Trash_Items_Directory (Base : String) return String is
     (if Is_Finder_Volume_Trash (Base) then Base else Hostkit.Fs.Join (Base, "files"));

   function Volume_Trash_For (Path : String) return String is separate;

   function Volume_Trash_Bases return Files.Types.String_Vectors.Vector is separate;

   procedure Remove_Orphan_Trash_Info is separate;

   function Trash_Base_Of (Trashed_Path : String) return String is separate;

   function Is_User_Visible_Mount_Point (Mount_Point : String; Runtime_Gvfs : String) return Boolean is separate;

   function Is_Volume_Trash_Item (Path : String) return Boolean is
      Base : constant String := Trash_Base_Of (Path);
   begin
      --  The Finder's own trash keeps no base of ours: its volume trashes
      --  are the .Trashes ones.
      return Base /= ""
        and then (if Trash_Backend_Of_Current_Environment = Trash_Macos_Native
                  then Is_Finder_Volume_Trash (Base)
                  else Base /= Trash_Base_Path);
   end Is_Volume_Trash_Item;

   function Path_Can_Be_Directory (Path : String) return Boolean is separate;

   function Two_Digit_Text (Value : Natural) return String is separate;

   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String
   is separate;

   function Trash_Is_Available return Boolean is separate;

   function Trash_Backend_Of_Current_Environment return Trash_Backend is separate;

   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result is separate;

   function Trash_Natively
     (Request : Native_Trash_Request)
      return Native_Trash_Result is separate;

   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result
   is separate;

   function Move_To_Trash
     (Path          : String;
      Trashed_Path  : out Files.Types.UString;
      Recorded_Path : String := "")
      return Mutation_Result
   is separate;

   function Move_To_Trash
     (Path : String)
      return Mutation_Result
   is
      Ignored : Files.Types.UString;
   begin
      return Move_To_Trash (Path, Ignored);
   end Move_To_Trash;

   function Delete_From_Trash_Backend
     (Trashed_Path : String)
      return Mutation_Result
   is separate;

   function Original_Path (Trashed_Path : String) return String is separate;

   function Restore_From_Trash_Backend
     (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
      return Mutation_Result
   is separate;

   function Is_Trash_Files_Directory (Path : String) return Boolean is
      Trash_Dir : constant String := Trash_Files_Directory;
   begin
      return Path /= ""
        and then Trash_Dir /= ""
        and then
          (Path = Trash_Dir
           or else Hostkit.Metadata.Same_File (Path, Trash_Dir));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return False;
   end Is_Trash_Files_Directory;

   function Trash_Original_Path (Trashed_Path : String) return String is
   begin
      if Recovery.Recognizes (Trashed_Path) then
         return Recovery.Original_Path (Trashed_Path);
      end if;
      return Original_Path (Trashed_Path);
   end Trash_Original_Path;

   function Is_Recovery_Payload (Path : String) return Boolean
     renames Recovery.Recognizes;

   function Release_Recovery_Payload (Path : String) return Mutation_Result is separate;

   function Registered_Recovery_Payloads return Files.Types.String_Vectors.Vector
     renames Recovery.Registered_Payloads;

   procedure Sweep_Recovery_Registry renames Recovery.Sweep_Registry;

   function Restore_From_Trash
     (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
      return Mutation_Result
   is
   begin
      if Recovery.Recognizes (Trashed_Path) then
         return Recovery.Restore (Trashed_Path, Expected_Identity, Expected_Original);
      end if;
      return Restore_From_Trash_Backend (Trashed_Path, Expected_Identity, Expected_Original);
   end Restore_From_Trash;

   function Preserve_For_Replace
     (Path : String; Recovery_Path : out Files.Types.UString) return Mutation_Result
   is separate;

   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result
   is
   begin
      if Recovery.Recognizes (Trashed_Path) then
         return Recovery.Discard (Trashed_Path);
      end if;
      return Delete_From_Trash_Backend (Trashed_Path);
   end Delete_Trashed_Item;

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

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean is separate;

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
   --  @param Settings Settings used for filetype, icon, and hidden-file policy.
   --  @param Wanted Which listed entries to build into items, besides folders.
   --  @param Judge The search's verdict on one built item.
   --  @param Max_Items How many matches to keep.
   --  @return The matches in walk order, and whether the walk was cut short.
   function Search_Tree
     (Root_Path : String;
      Settings  : Files.Settings.Settings_Model;
      Wanted    : not null access function (Name : String; Kind : Files.Types.Item_Kind) return Boolean;
      Judge     : not null access function (Item : Directory_Item) return Search_Verdict;
      Max_Items : Natural)
      return Recursive_Search_Result is separate;

   function Search_Contents
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model)
      return Recursive_Search_Result is separate;

   function Search_Names
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := Max_Search_Results)
      return Recursive_Search_Result
   is separate;

   function Root_Label (Path : String; Kind : Root_Kind) return String is separate;

   function Root_Name (Path : String; Kind : Root_Kind) return String is separate;

   function Available_Root_Entries return Root_Entry_Vectors.Vector is separate;

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

   function Supports_Permissions return Boolean is separate;

   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural is separate;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result
   is separate;

   function Supports_Ownership return Boolean is separate;

   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id is separate;

   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id is separate;

   function User_Name_For_Id (Id : Files.Types.Account_Id) return String renames Account_Names.User_Name;

   function Group_Name_For_Id (Id : Files.Types.Account_Id) return String renames Account_Names.Group_Name;

   subtype Update_Field is Hostkit.Metadata.Identity_Field;

   --  The one mutation behind Change_Mode, Change_Access and
   --  Change_Ownership: verify the recorded identity (when there is one),
   --  update through the held entry, and report the value it had and the
   --  identity actually changed. A previous value above Max_Previous is
   --  refused rather than truncated. Access_Text and the two access records
   --  are a permission update's, as Hostkit.Metadata.Update_Entry_Metadata
   --  has them.
   function Update_Verified_Entry
     (Path, Expected_Identity : String; Kind : Hostkit.Metadata.Metadata_Update_Kind;
      Value, Group, Max_Previous : Update_Field; Owner_Name, Group_Name, Access_Text : String;
      Previous, Previous_Group : out Update_Field;
      Previous_Access, Applied_Access, Identity : out Files.Types.UString) return Boolean
   is separate;

   function Change_Access
     (Path, Expected_Identity : String; Mode : Natural; Access_Text : String;
      Previous : out Natural; Previous_Access, Applied_Access, Identity : out Files.Types.UString)
      return Mutation_Result
   is separate;

   function Change_Mode
     (Path, Expected_Identity : String; Mode : Natural;
      Previous : out Natural; Identity : out Files.Types.UString) return Mutation_Result
   is
      Unused_Previous_Access, Unused_Applied_Access : Files.Types.UString;
   begin
      return Change_Access
        (Path, Expected_Identity, Mode, "", Previous, Unused_Previous_Access, Unused_Applied_Access, Identity);
   end Change_Mode;

   function Change_Ownership
     (Path, Expected_Identity : String; User_Id, Group_Id : Files.Types.Account_Id;
      Previous_User, Previous_Group : out Files.Types.Account_Id; Identity : out Files.Types.UString;
      Owner_Name : String := ""; Group_Name : String := "") return Mutation_Result
   is separate;

   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result is
   begin
      Files.Io_Errors.Reset;
      Support.Copy_To_New_Path (Source_Path, Destination_Path, Batch => Batch);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return
           (Success   => False,
            Error_Key => Files.Io_Errors.Error_Key ("error.copy.failed"));
   end Copy_Tree;

   function Copy_Tree
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result is separate;

   function Delete_Permanently
     (Path : String)
      return Mutation_Result
   is separate;

   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result
   is separate;

   function Execute_Drop_Import
     (Plans   : Drop_Import_Plan_Vectors.Vector;
      Created : out Created_Entry_Vectors.Vector;
      Cancel  : Cancellation_Check := Job_Cancelled;
      Batch   : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result
   is separate;

   function Import_Replacing
     (Source, Destination   : String;
      Mode                  : Drop_Import_Mode;
      Replace               : Boolean;
      Replaced              : out Files.Types.UString;
      Replaced_Identity     : out Files.Types.UString;
      Created_Identity      : out Files.Types.UString;
      Created_Tree_Revision : out Files.Types.UString;
      Preserved             : access procedure (Backup, Backup_Identity : String) := null;
      Cancel                : Cancellation_Check := Job_Cancelled;
      Batch                 : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result
   is separate;

   procedure Put_Back_Replaced
     (Replaced, Replaced_Identity : in out Files.Types.UString;
      Destination                 : String;
      Result                      : in out Mutation_Result)
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

   function Publish_Staged
     (Staged   : String;
      Target   : String;
      Identity : out UString;
      Revision : out UString)
      return Boolean
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
        and then Files.Fs_Primitives.Entry_Exists (Path)
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
