with Files.Diagnostics;
with Ada.Unchecked_Deallocation;
with GNAT.Directory_Operations;

with Hostkit.Fs;
with Hostkit.Path_Text;
with Hostkit.Regular_Files;

package body Files.Fs_Primitives is
   use type Hostkit.Fs.Delete_Tree_Outcome;
   use type Hostkit.Fs.Entry_Kind;

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
      Dir : GNAT.Directory_Operations.Dir_Type;
      type Name_Buffer is access String;
      procedure Free is new Ada.Unchecked_Deallocation (String, Name_Buffer);
      --  On the heap: callers recurse, and a frame per level adds up.
      Buffer : Name_Buffer := new String (1 .. 65_536);
      Last   : Natural;
      Stop   : Boolean := False;
   begin
      GNAT.Directory_Operations.Open (Dir, Path);
      loop
         GNAT.Directory_Operations.Read (Dir, Buffer.all, Last);
         exit when Last = 0;
         if Last = Buffer'Last then
            raise Ada.Directories.Use_Error;
         end if;
         if Buffer (1 .. Last) /= "." and then Buffer (1 .. Last) /= ".." then
            Visit (Buffer (1 .. Last), Stop);
            exit when Stop;
         end if;
      end loop;
      GNAT.Directory_Operations.Close (Dir);
      Free (Buffer);
   exception
      when others =>
         Free (Buffer);
         if GNAT.Directory_Operations.Is_Open (Dir) then
            begin
               GNAT.Directory_Operations.Close (Dir);
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.Fs_Primitives");
            end;
         end if;
         raise;
   end For_Each_Name;

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

end Files.Fs_Primitives;
