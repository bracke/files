with Files.Diagnostics;
with Ada.Strings.Unbounded;

with Hostkit.Directory_Listing;
with Hostkit.Host;
with Hostkit.Path_Text;
with Hostkit.Regular_Files;

--  Every by-path call here asks Hostkit, never GNAT's runtime directly, so
--  each reaches any depth on every host.
package body Files.Fs_Primitives is
   use type Hostkit.Fs.Delete_Tree_Outcome;
   use type Hostkit.Fs.Entry_Kind;
   use type Hostkit.Host.Kind;

   function Exists (Path : String) return Boolean is
     (Hostkit.Fs.Kind_Of (Path) /= Hostkit.Fs.Missing_Entry);

   function Entry_Exists (Path : String) return Boolean is
   begin
      return Path /= "" and then (Exists (Path) or else Hostkit.Fs.Is_Link (Path));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Fs_Primitives");
         return False;
   end Entry_Exists;

   function File_Exists (Path : String) return Boolean is
     (Hostkit.Fs.Kind_Of (Path) = Hostkit.Fs.Ordinary_File_Entry);

   function Directory_Exists (Path : String) return Boolean is
     (Hostkit.Fs.Kind_Of (Path) = Hostkit.Fs.Directory_Entry);

   function Open_Regular_Read
     (Path : String) return GNAT.OS_Lib.File_Descriptor
   is
      Supported : Boolean;
   begin
      for Value of Path loop
         if Value = ASCII.NUL then
            return GNAT.OS_Lib.Invalid_FD;
         end if;
      end loop;
      return Hostkit.Regular_Files.Open_Read (Path, False, Supported);
   end Open_Regular_Read;

   function Open_Regular_Read_Following_Links
     (Path : String) return GNAT.OS_Lib.File_Descriptor
   is
      Supported : Boolean;
   begin
      for Value of Path loop
         if Value = ASCII.NUL then
            return GNAT.OS_Lib.Invalid_FD;
         end if;
      end loop;
      return Hostkit.Regular_Files.Open_Read (Path, True, Supported);
   end Open_Regular_Read_Following_Links;

   procedure Delete_Tree (Path : String) is
   begin
      if not Exists (Path) and then not Hostkit.Fs.Is_Link (Path) then
         return;
      end if;
      if Hostkit.Fs.Delete_Tree_No_Follow (Path) /= Hostkit.Fs.Tree_Deleted then
         raise Ada.Directories.Use_Error;
      end if;
   end Delete_Tree;

   function Leaf_Text (Path : String) return String renames Hostkit.Path_Text.Leaf;

   function Parent_Text (Path : String) return String renames Hostkit.Path_Text.Parent;

   function Compose_Text (Directory : String; Stem : String; Extension : String := "") return String is
     (Hostkit.Fs.Join (Directory, (if Extension = "" then Stem else Stem & "." & Extension)));

   function Kind (Path : String) return Ada.Directories.File_Kind is
   begin
      case Hostkit.Fs.Kind_Of (Path) is
         when Hostkit.Fs.Missing_Entry =>
            raise Ada.Directories.Name_Error;
         when Hostkit.Fs.Directory_Entry =>
            return Ada.Directories.Directory;
         when Hostkit.Fs.Ordinary_File_Entry =>
            return Ada.Directories.Ordinary_File;
         when Hostkit.Fs.Special_File_Entry =>
            return Ada.Directories.Special_File;
      end case;
   end Kind;

   procedure For_Each_Name
     (Path  : String;
      Visit : not null access procedure (Name : String; Stop : in out Boolean))
   is
      Entries : Hostkit.Directory_Listing.Entry_Vectors.Vector;
      Stop    : Boolean := False;
   begin
      if not Hostkit.Directory_Listing.List (Path, Entries) then
         raise Ada.Directories.Use_Error;
      end if;
      for Listed of Entries loop
         Visit (Listed.Name, Stop);
         exit when Stop;
      end loop;
   end For_Each_Name;

   procedure For_Each_Listed
     (Path  : String;
      Visit : not null access procedure (Name : String; Kind : Hostkit.Fs.Entry_Kind; Stop : in out Boolean))
   is
      Entries : Hostkit.Directory_Listing.Entry_Vectors.Vector;
      Stop    : Boolean := False;
   begin
      if not Hostkit.Directory_Listing.List (Path, Entries) then
         raise Ada.Directories.Use_Error;
      end if;
      for Listed of Entries loop
         Visit
           (Listed.Name,
            (case Listed.Kind is
               when Hostkit.Directory_Listing.Regular_File => Hostkit.Fs.Ordinary_File_Entry,
               when Hostkit.Directory_Listing.Directory => Hostkit.Fs.Directory_Entry,
               when Hostkit.Directory_Listing.Other => Hostkit.Fs.Special_File_Entry,
               when Hostkit.Directory_Listing.Symbolic_Link | Hostkit.Directory_Listing.Unknown =>
                 Hostkit.Fs.Kind_Of (Hostkit.Fs.Join (Path, Listed.Name))),
            Stop);
         exit when Stop;
      end loop;
   end For_Each_Listed;

   function Parent_Directory (Path : String) return String is
      Parent : constant String := Parent_Text (Path);
      Leaf   : constant String := Leaf_Text (Path);
   begin
      --  A name alone lies in the current directory, as
      --  Ada.Directories.Containing_Directory says.
      if Parent = "" and then Leaf not in "" | "." | ".." and then Hostkit.Path_Text.Root_Length (Path) = 0 then
         return ".";
      end if;
      return Parent;
   end Parent_Directory;

   function Absolute_Name (Path : String) return String is
     (Hostkit.Path_Text.Absolute (Path, Hostkit.Fs.Current_Directory));

   --  Whole (absolute) with the links of its deepest part that is there
   --  resolved, the rest of its text kept after it, as Normalize_Pathname
   --  reads a path that is not all there: a dangling link is read as the
   --  text it holds. Links counts the links followed so far, so a loop of
   --  dangling links ends.
   function Resolved (Whole : String; Links : Natural := 0) return String is
      Most_Links : constant := 40;
      Real       : constant String := Hostkit.Fs.Real_Path (Whole);
   begin
      if Real /= "" then
         declare
            Result : constant String (1 .. Real'Length) := Real;
         begin
            return Result;
         end;
      end if;
      declare
         Parent : constant String := Parent_Text (Whole);
      begin
         if Parent = "" or else Parent = Whole then
            return Whole;
         end if;
         declare
            Base   : constant String := Resolved (Parent, Links);
            Joined : constant String := Hostkit.Fs.Join (Base, Leaf_Text (Whole));
            Target : Ada.Strings.Unbounded.Unbounded_String;
         begin
            if Links < Most_Links
              and then Hostkit.Fs.Read_Link_Target (Joined, Target)
              and then Ada.Strings.Unbounded.Length (Target) > 0
            then
               return Resolved
                 (Hostkit.Path_Text.Absolute (Ada.Strings.Unbounded.To_String (Target), Base), Links + 1);
            end if;
            return Joined;
         end;
      end;
   end Resolved;

   function Full_Name (Path : String) return String is
      Whole : constant String := Absolute_Name (Path);
   begin
      --  GNAT's Windows Full_Name is GetFullPathName, the text alone; its
      --  POSIX one resolves links.
      if Whole = "" or else Hostkit.Host.Current = Hostkit.Host.Windows then
         return Whole;
      end if;
      return Resolved (Whole);
   end Full_Name;

   function Real_Name (Path : String) return String is
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         return Full_Name (Path);
      end if;
      declare
         Whole : constant String := Absolute_Name (Path);
      begin
         return (if Whole = "" then "" else Resolved (Whole));
      end;
   end Real_Name;

   procedure Create_Directory (Path : String) is
   begin
      if not Hostkit.Fs.Create_Directory (Path) then
         raise Ada.Directories.Use_Error;
      end if;
   end Create_Directory;

   procedure Create_Path (Path : String) is
   begin
      if not Hostkit.Fs.Create_Path (Path) then
         raise Ada.Directories.Use_Error;
      end if;
   end Create_Path;

   procedure Delete_File (Path : String) is
   begin
      if not Hostkit.Fs.Delete_File (Path) then
         if Entry_Exists (Path) then
            raise Ada.Directories.Use_Error;
         end if;
         raise Ada.Directories.Name_Error;
      end if;
   end Delete_File;

   procedure Delete_Directory (Path : String) is
   begin
      if not Hostkit.Fs.Delete_Empty_Directory (Path) then
         if Hostkit.Fs.Is_Link (Path) or else not Directory_Exists (Path) then
            raise Ada.Directories.Name_Error;
         end if;
         raise Ada.Directories.Use_Error;
      end if;
   end Delete_Directory;

   function Size (Path : String) return Ada.Directories.File_Size is
     (Hostkit.Fs.Size_Of (Path, Follow_Links => True));

   function Modification_Time (Path : String) return Ada.Calendar.Time is
     (Hostkit.Fs.Modification_Time_Of (Path, Follow_Links => True));

end Files.Fs_Primitives;
