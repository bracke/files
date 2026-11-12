with Hostkit.Path_Text;

separate (Files.File_System)
function Delete_Permanently
  (Path : String)
   return Mutation_Result
is
   function Has_Navigation_Component return Boolean is
      First : Positive := Path'First;
   begin
      for Index in Path'Range loop
         if Hostkit.Fs.Is_Separator (Path (Index)) then
            if Index > First
              and then Path (First .. Index - 1) in "." | ".."
            then
               return True;
            end if;
            First := Index + 1;
         end if;
      end loop;
      return First <= Path'Last
        and then Path (First .. Path'Last) in "." | "..";
   end Has_Navigation_Component;

   --  A root of any spelling -- "/", "C:\", "\\server\share", "\\?\C:\" --
   --  has no leaf (Hostkit.Path_Text), and is never deleted whole.
   function Unsafe_Target return Boolean is
   begin
      if Path = ""
        or else Hostkit.Path_Text.Leaf (Path) = ""
        or else Has_Navigation_Component
      then
         return True;
      end if;

      --  Absolute, with a leaf and no "." or "..": not a root. Asked no
      --  further, so a path past GNAT's Windows limits is not refused.
      if Hostkit.Fs.Is_Link (Path) or else Hostkit.Path_Text.Root_Length (Path) > 0 then
         return False;
      end if;

      declare
         Full : constant String := Files.Fs_Primitives.Full_Name (Path);
      begin
         return Full = "" or else Files.Fs_Primitives.Parent_Text (Full) = "";
      end;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return True;
   end Unsafe_Target;
begin
   Files.Io_Errors.Reset;
   if Unsafe_Target then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.permanent_delete.refused"));
   elsif not Files.Fs_Primitives.Entry_Exists (Path) then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.path.missing"));
   end if;

   --  Symlink-aware recursive delete: a symlink -- even one whose target is
   --  a directory -- is unlinked as a link and never followed, so deleting a
   --  link (or a folder that merely contains one) can never reach through
   --  into the link target's real contents, as Ada.Directories.Delete_Tree,
   --  which follows links, would.
   Files.Io_Errors.Clear_Os_Error;
   Files.Fs_Primitives.Delete_Tree (Path);
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      --  The delete raises straight from the refused unlink or rmdir, so
      --  errno still says why.
      Files.Io_Errors.Capture;
      return
        (Success   => False,
         Error_Key => Files.Io_Errors.Error_Key ("error.permanent_delete.failed"));
end Delete_Permanently;
