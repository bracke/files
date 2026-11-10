separate (Files.File_System)
--  Names read straight from the directory: no stat per entry (Ada.Directories'
--  search makes one, on the UI thread whenever the info pane shows a folder),
--  and a dangling link counted, as the listing shows it.
function Directory_Count_Token (Path : String) return String is
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
      return "";
   end if;
   Files.Fs_Primitives.For_Each_Name (Path, Count_One'Access);
   return "directory.count|" & Natural_Text (Count) & (if Capped then "+" else "");
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return "";
end Directory_Count_Token;
