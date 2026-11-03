with GNAT.Directory_Operations;

separate (Files.File_System)
--  Names read straight from the directory: no stat per entry (Ada.Directories'
--  search makes one, on the UI thread whenever the info pane shows a folder),
--  and a dangling link counted, as the listing shows it.
function Directory_Count_Token (Path : String) return String is
   Dir    : GNAT.Directory_Operations.Dir_Type;
   Buffer : String (1 .. 4_096);
   Last   : Natural;
   Count  : Natural := 0;
   Capped : Boolean := False;
begin
   if not Files.Fs_Primitives.Directory_Exists (Path)
   then
      return "";
   end if;

   GNAT.Directory_Operations.Open (Dir, Path);
   loop
      GNAT.Directory_Operations.Read (Dir, Buffer, Last);
      exit when Last = 0;
      if Buffer (1 .. Last) /= "." and then Buffer (1 .. Last) /= ".." then
         if Count = Max_Directory_Count_Entries then
            Capped := True;
            exit;
         end if;
         Count := Count + 1;
      end if;
   end loop;
   GNAT.Directory_Operations.Close (Dir);
   return "directory.count|" & Natural_Text (Count) &
     (if Capped then "+" else "");
exception
   when others =>
      if GNAT.Directory_Operations.Is_Open (Dir) then
         GNAT.Directory_Operations.Close (Dir);
      end if;
      return "";
end Directory_Count_Token;
