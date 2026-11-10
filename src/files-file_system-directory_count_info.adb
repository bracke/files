separate (Files.File_System)
--  Names read straight from the directory: no stat per entry (Ada.Directories'
--  search makes one, on the UI thread whenever the info pane shows a folder),
--  and a dangling link counted, as the listing shows it.
function Directory_Count_Info (Path : String) return Files.Extra_Info.Info is
   Count  : Natural := 0;
   Capped : Boolean := False;

   procedure Count_One (Name : String; Stop : in out Boolean) is
      pragma Unreferenced (Name);
   begin
      if Count = Max_Directory_Count_Entries then
         Capped := True;
         Stop := True;
      else
         Count := Count + 1;
      end if;
   end Count_One;
begin
   if not Files.Fs_Primitives.Directory_Exists (Path) then
      return Files.Extra_Info.No_Info;
   end if;
   Files.Fs_Primitives.For_Each_Name (Path, Count_One'Access);
   return Files.Extra_Info.Make (Files.Extra_Info.Directory_Count, Count => Count, Capped => Capped);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Files.Extra_Info.No_Info;
end Directory_Count_Info;
