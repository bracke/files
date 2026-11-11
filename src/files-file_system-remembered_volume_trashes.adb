separate (Files.File_System)
function Remembered_Volume_Trashes return Files.Types.String_Vectors.Vector is
   Data   : constant String := Support.Application_Data_Directory;
   List   : constant String :=
     (if Data = "" then "" else Hostkit.Fs.Join (Hostkit.Fs.Join (Data, "files"), "volume-trashes"));
   Result : Files.Types.String_Vectors.Vector;
   File   : Ada.Text_IO.File_Type;
   Line   : Unbounded_String;
   Complete : Boolean;
begin
   if List = "" or else Hostkit.Fs.Is_Link (List) or else not Ada.Directories.Exists (List) then
      return Result;
   end if;
   Ada.Text_IO.Open (File, Ada.Text_IO.In_File, List);
   while not Ada.Text_IO.End_Of_File (File)
     and then Natural (Result.Length) < Max_Remembered_Volume_Trashes
   loop
      Files.Bounded_Text_IO.Read_Line (File, 4_096, Line, Complete);
      if Complete and then Length (Line) > 0 and then GNAT.OS_Lib.Is_Absolute_Path (To_String (Line)) then
         Result.Append (Line);
      end if;
   end loop;
   Ada.Text_IO.Close (File);
   return Result;
exception
   when Swallowed : others =>
      if Ada.Text_IO.Is_Open (File) then
         Ada.Text_IO.Close (File);
      end if;
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Result;
end Remembered_Volume_Trashes;
