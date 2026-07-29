with Ada.Environment_Variables;
with Ada.Strings.Unbounded;

with Hostkit.Fs;

package body Files.File_System.Support is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   procedure Safe_End_Search
     (Search  : in out Ada.Directories.Search_Type;
      Started : in out Boolean) is
   begin
      if Started then
         begin
            Ada.Directories.End_Search (Search);
         exception
            when others =>
               null;
         end;
         Started := False;
      end if;
   end Safe_End_Search;

   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type) is
   begin
      if Ada.Text_IO.Is_Open (File) then
         begin
            Ada.Text_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Close;

   procedure Safe_Close
     (File : in out Ada.Streams.Stream_IO.File_Type) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         begin
            Ada.Streams.Stream_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Close;

   function Safe_Environment_Value
     (Name : String)
      return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;

      return "";
   exception
      when others =>
         return "";
   end Safe_Environment_Value;

   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean is
   begin
      return Files.Types.To_Lower (Safe_Environment_Value (Name)) = Expected;
   end Environment_Equals;

   function Image_No_Space (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Image_No_Space;

   function Starts_With
     (Value  : String;
      Prefix : String)
      return Boolean is
   begin
      return Value'Length >= Prefix'Length
        and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Natural_Text (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Natural_Text;

   --  Recursively copy a file/directory tree. Used as the cross-device
   --  fallback when Ada.Directories.Rename fails with EXDEV (it cannot move
   --  across filesystems), by both trashing and drag-and-drop moves.
   procedure Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Depth            : Natural := 0)
   is
      --  A copy of a folder that (directly or transitively) contains a symlink to
      --  an ancestor would, without this cap, recurse until the path exceeds
      --  PATH_MAX. The symlink guard below removes that cause; this is a defensive
      --  backstop far beyond any real directory nesting. Reaching it raises, which
      --  fails the whole copy (see the function wrapper) rather than silently
      --  truncating -- important because a cross-device MOVE deletes the source
      --  only after a successful copy.
      Max_Copy_Depth : constant := 1024;

      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      --  Preserve a symlink as a link instead of following it. Ada.Directories.Kind
      --  dereferences links, so classifying by it would copy the link's *target*
      --  (losing the link, or -- for a link to an ancestor -- exploding into an
      --  unbounded recursive copy). Recreate the link verbatim and stop. This
      --  mirrors the search/size walkers, which also skip links via Hostkit.Fs.
      if Hostkit.Fs.Is_Link (Source_Path) then
         declare
            Target  : Ada.Strings.Unbounded.Unbounded_String;
            Created : Boolean := False;
         begin
            if Hostkit.Fs.Read_Link_Target (Source_Path, Target) then
               Created := Hostkit.Fs.Create_Link (To_String (Target), Destination_Path);
            end if;

            --  If the link cannot be recreated (unreadable target, or a host
            --  that refuses link creation, e.g. Windows without the privilege),
            --  raise rather than silently omit it. Copy_Tree is the copy step of
            --  the cross-device MOVE fallback, which deletes the source only
            --  after it returns: silently dropping the link and then deleting
            --  the original would lose it. Raising aborts the copy so the move
            --  keeps the source; the function wrapper maps this to
            --  error.copy.failed.
            if not Created then
               raise Program_Error;
            end if;
         end;
         return;
      end if;

      if Depth > Max_Copy_Depth then
         --  Backstop only; the message would be caught and mapped to
         --  error.copy.failed by the function wrapper, never shown to the user.
         raise Program_Error;
      end if;

      case Ada.Directories.Kind (Source_Path) is
         when Ada.Directories.Directory =>
            Ada.Directories.Create_Directory (Destination_Path);
            Ada.Directories.Start_Search
              (Search,
               Directory => Source_Path,
               Pattern   => "*",
               Filter    =>
                 [Ada.Directories.Ordinary_File => True,
                  Ada.Directories.Directory     => True,
                  Ada.Directories.Special_File  => True]);
            Started := True;
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
               declare
                  Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
               begin
                  if Name /= "." and then Name /= ".." then
                     Copy_Tree
                       (Ada.Directories.Full_Name (Dir_Entry),
                        Join_Path (Destination_Path, Name),
                        Depth + 1);
                  end if;
               end;
            end loop;
            Safe_End_Search (Search, Started);
         when Ada.Directories.Ordinary_File =>
            Ada.Directories.Copy_File (Source_Path, Destination_Path);
         when Ada.Directories.Special_File =>
            Ada.Directories.Copy_File (Source_Path, Destination_Path);
      end case;
   exception
      when others =>
         Safe_End_Search (Search, Started);
         raise;
   end Copy_Tree;

   procedure Delete_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      --  Unlink a symlink as a link, never following it: Ada.Directories.Kind
      --  and Delete_Tree dereference links, so classifying by Kind would let a
      --  recursive delete walk into and wipe the link target's real contents
      --  (e.g. Shift-Delete of a symlink to ~/Pictures). Mirrors Copy_Tree.
      if Hostkit.Fs.Is_Link (Path) then
         if not Hostkit.Fs.Delete_Link (Path) then
            raise Program_Error;
         end if;
         return;
      end if;

      case Ada.Directories.Kind (Path) is
         when Ada.Directories.Directory =>
            Ada.Directories.Start_Search
              (Search,
               Directory => Path,
               Pattern   => "*",
               Filter    =>
                 [Ada.Directories.Ordinary_File => True,
                  Ada.Directories.Directory     => True,
                  Ada.Directories.Special_File  => True]);
            Started := True;
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
               declare
                  Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
               begin
                  if Name /= "." and then Name /= ".." then
                     --  Recurse by path so the link check above re-applies to
                     --  every entry, guarding nested symlinks too.
                     Delete_Tree (Ada.Directories.Full_Name (Dir_Entry));
                  end if;
               end;
            end loop;
            Safe_End_Search (Search, Started);
            Ada.Directories.Delete_Directory (Path);
         when Ada.Directories.Ordinary_File | Ada.Directories.Special_File =>
            Ada.Directories.Delete_File (Path);
      end case;
   exception
      when others =>
         Safe_End_Search (Search, Started);
         raise;
   end Delete_Tree;

end Files.File_System.Support;
