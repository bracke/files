separate (Files.File_System)
function Delete_Permanently
  (Path : String)
   return Mutation_Result
is
   Windows : constant Boolean := Files_Config.Alire_Host_OS = "windows";

   function Has_Navigation_Component return Boolean is
      First : Positive := Path'First;
   begin
      for Index in Path'Range loop
         if Path (Index) = '/'
           or else (Windows and then Path (Index) = '\')
         then
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

   function Unsafe_Target return Boolean is
   begin
      if Path = ""
        or else Path = "/"
        or else
          (Windows
           and then Path'Length = 3
           and then Path (Path'First + 1) = ':'
           and then Path (Path'First + 2) in '/' | '\')
        or else Has_Navigation_Component
      then
         return True;
      end if;

      if Hostkit.Fs.Is_Link (Path) then
         return False;
      end if;

      declare
         Full   : constant String := Ada.Directories.Full_Name (Path);
         Parent : constant String := Ada.Directories.Containing_Directory (Full);
      begin
         return Full = ""
           or else Full = Parent
           or else (Full'Length = 1 and then Full (Full'First) = '/');
      end;
   exception
      when others =>
         return True;
   end Unsafe_Target;
begin
   Files.Io_Errors.Reset;
   if Unsafe_Target then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.permanent_delete.refused"));
   elsif not (Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path)) then
      return
        (Success   => False,
         Error_Key => To_Unbounded_String ("error.rename.source_missing"));
   end if;

   --  Symlink-aware recursive delete: a symlink -- even one whose target is
   --  a directory -- is unlinked as a link and never followed, so deleting a
   --  link (or a folder that merely contains one) can never reach through
   --  into the link target's real contents. Ada.Directories.Delete_Tree,
   --  used previously via Files.Fs, follows links and would.
   Files.Io_Errors.Clear_Os_Error;
   Support.Delete_Tree (Path);
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when others =>
      --  The delete raises straight from the refused unlink or rmdir, so
      --  errno still says why.
      Files.Io_Errors.Capture;
      return
        (Success   => False,
         Error_Key => Files.Io_Errors.Error_Key ("error.permanent_delete.failed"));
end Delete_Permanently;
