with Files.Diagnostics;
with Ada.Directories;
with Ada.Unchecked_Deallocation;
with GNAT.Directory_Operations;

with Hostkit.Fs;
with Hostkit.Path_Text;
with Hostkit.Regular_Files;

package body Files.Fs_Primitives is
   use type Ada.Directories.File_Kind;
   use type Hostkit.Fs.Delete_Tree_Outcome;

   function Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
   end Exists;

   function Entry_Exists (Path : String) return Boolean is
   begin
      return Path /= "" and then (Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Fs_Primitives");
         return False;
   end Entry_Exists;

   function File_Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Fs_Primitives");
         return False;
   end File_Exists;

   function Directory_Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Directory;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Fs_Primitives");
         return False;
   end Directory_Exists;

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
      if not Ada.Directories.Exists (Path) and then not Hostkit.Fs.Is_Link (Path) then
         return;
      end if;
      if Hostkit.Fs.Delete_Tree_No_Follow (Path) /= Hostkit.Fs.Tree_Deleted then
         raise Ada.Directories.Use_Error;
      end if;
   end Delete_Tree;

   --  The last index of Path before its trailing separators.
   function Content_Last (Path : String) return Natural is
      Last : Natural := Path'Last;
   begin
      while Last >= Path'First and then Hostkit.Path_Text.Is_Separator_In (Path, Path (Last)) loop
         Last := Last - 1;
      end loop;
      return Last;
   end Content_Last;

   --  Where Path's last component starts (Content_Last + 1 for none).
   function Leaf_First (Path : String) return Positive is
      First : Positive := Content_Last (Path) + 1;
   begin
      while First > Path'First and then not Hostkit.Path_Text.Is_Separator_In (Path, Path (First - 1)) loop
         First := First - 1;
      end loop;
      return First;
   end Leaf_First;

   function Leaf_Text (Path : String) return String is
      Last  : constant Natural := Content_Last (Path);
      First : constant Positive := Leaf_First (Path);
   begin
      --  A drive ("C:") is a root, not a name.
      if Last < First or else Path (Last) = ':' then
         return "";
      end if;
      return Path (First .. Last);
   end Leaf_Text;

   function Parent_Text (Path : String) return String is
      First : constant Positive := Leaf_First (Path);
      Last  : Natural := First - 1;
   begin
      if Leaf_Text (Path) = "" then
         return "";
      end if;
      --  The separators before the leaf, all but a root's own.
      while Last > Path'First and then Hostkit.Path_Text.Is_Separator_In (Path, Path (Last))
        and then not (Last = Path'First + 2 and then Path (Path'First + 1) = ':')
      loop
         Last := Last - 1;
      end loop;
      return Path (Path'First .. Last);
   end Parent_Text;

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
   begin
      if Path = "" then
         return "";
      end if;

      declare
         --  Containing_Directory resolves the parent cross-platform, trimming
         --  the final path component and handling trailing separators. It
         --  raises Use_Error at a filesystem root, where no parent exists.
         Parent : constant String := Ada.Directories.Containing_Directory (Path);
      begin
         if Parent = "" or else Parent = Path then
            return "";
         end if;

         return Parent;
      end;
   exception
      when Refused : Ada.Directories.Name_Error =>
         --  A name GNAT will not parse (Leaf_Text); a root raises Use_Error.
         Files.Diagnostics.Note (Refused, "Files.Fs_Primitives");
         return Parent_Text (Path);
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Fs_Primitives");
         return "";
   end Parent_Directory;

end Files.Fs_Primitives;
