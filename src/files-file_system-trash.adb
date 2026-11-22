with Files.Protocol_Names;
with Files.IO.Fs_Primitives;
with Ada.Streams;
with Files.Environment;
with Files.Diagnostics;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Hostkit.Metadata;
with Hostkit.Fs;
with Hostkit.Host;
with Files.Leaf_Names;
with Files.File_System.Support;
with Files.File_System.Recovery;
with Files.File_System.Roots;
with Files.File_System.Permissions;
with Files.File_Identities;
with Files.IO.Private_Directories;
with Files.IO.Errors;
with Hostkit.Trash;
with Files.IO.Bounded_Text;
with Files.Name_Parts;
with Files.Text_Case;

package body Files.File_System.Trash is

   use type Hostkit.Host.Kind;

   use Files.File_System.Support;
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   --  Whether environment variable Name equals Expected, compared
   --  case-insensitively.
   --
   --  @param Name Environment variable name.
   --  @param Expected Value to compare against.
   --  @return True when the variable's value equals Expected.
   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean;

   --  The list of remembered volume trashes in Files_Data_Directory
   --  (Protocol_Names.Volume_Trash_List).
   --
   --  @return The list's path, or "" when Files_Data_Directory has no name.
   function Volume_Trash_List_Path return String;

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

   --  What a freedesktop trash info file's name adds to its item's name.
   Trash_Info_Suffix : constant String := ".trashinfo";

   --  The folder of a freedesktop trash base that holds its info files.
   function Trash_Info_Directory (Base : String) return String;

   --  The info file of the item named Leaf in a freedesktop trash base.
   function Trash_Info_Path (Base, Leaf : String) return String;

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

   function Original_Path (Trashed_Path : String) return String;

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
               if Head = Top or else Files.Text_Case.Fold_Case (Head) = Files.Text_Case.Fold_Case (Top) then
                  return Path (Last + 1 .. Path'Last);
               end if;
            end;
         end if;
      end loop;
      return "";
   end Relative_To_Top;

   function Volume_Trash_Top (Base : String) return String is
     (if Files.Name_Parts.Leaf_Of (Base) (1 .. Natural'Min (7, Files.Name_Parts.Leaf_Of (Base)'Length))
           = ".Trash-"
      then Files.IO.Fs_Primitives.Parent_Directory (Base)
      else Files.IO.Fs_Primitives.Parent_Directory (Files.IO.Fs_Primitives.Parent_Directory (Base)));

   function Is_Finder_Volume_Trash (Base : String) return Boolean is
     (Base /= ""
      and then Files.Name_Parts.Leaf_Of (Files.IO.Fs_Primitives.Parent_Directory (Base)) = ".Trashes");

   function Trash_Items_Directory (Base : String) return String is
     (if Is_Finder_Volume_Trash (Base) then Base else Hostkit.Fs.Join (Base, "files"));

   function Trash_Info_Directory (Base : String) return String is (Hostkit.Fs.Join (Base, "info"));

   function Trash_Info_Path (Base, Leaf : String) return String is
     (Hostkit.Fs.Join (Trash_Info_Directory (Base), Leaf & Trash_Info_Suffix));

   function Volume_Trash_For (Path : String) return String is separate;

   function Volume_Trash_Bases return Files.Types.String_Vectors.Vector is separate;

   procedure Remove_Orphan_Info_Files is separate;

   function Trash_Base_Of (Trashed_Path : String) return String is separate;

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

   function Volume_Trash_Item_Directories return Files.Types.String_Vectors.Vector is
      Result : Files.Types.String_Vectors.Vector;
   begin
      for Base of Volume_Trash_Bases loop
         Result.Append (To_Unbounded_String (Trash_Items_Directory (To_String (Base))));
      end loop;
      return Result;
   end Volume_Trash_Item_Directories;

   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean is
   begin
      return Files.Text_Case.To_Lower_Ascii (Files.Environment.Value (Name)) = Expected;
   end Environment_Equals;

   function Volume_Trash_List_Path return String is
      App : constant String := Files_Data_Directory;
   begin
      return (if App = "" then "" else Hostkit.Fs.Join (App, Files.Protocol_Names.Volume_Trash_List));
   end Volume_Trash_List_Path;

end Files.File_System.Trash;
