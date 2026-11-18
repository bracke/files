separate (Files.File_System)
function Remembered_Volume_Trashes (Complete : out Boolean) return Files.Types.String_Vectors.Vector is
   List   : constant String := Support.Volume_Trash_List_Path;
   Result : Files.Types.String_Vectors.Vector;
   File   : Ada.Text_IO.File_Type;
   Line   : Unbounded_String;
   Whole_Line : Boolean;
begin
   Complete := False;
   if List = "" then
      return Result;
   elsif Hostkit.Fs.Is_Link (List) or else Files.Fs_Primitives.Entry_Is_Absent (List) then
      --  No list yet, or a link where ours belongs, which a written list
      --  replaces without following: nothing of ours to lose.
      Complete := True;
      return Result;
   end if;
   Hostkit.Fs.Open_Text (File, Ada.Text_IO.In_File, List);
   while not Ada.Text_IO.End_Of_File (File)
     and then Natural (Result.Length) < Max_Remembered_Volume_Trashes
   loop
      Files.Bounded_Text_IO.Read_Line (File, 4_096, Line, Whole_Line);
      if Whole_Line and then Length (Line) > 0 and then GNAT.OS_Lib.Is_Absolute_Path (To_String (Line)) then
         Result.Append (Line);
      end if;
   end loop;
   Ada.Text_IO.Close (File);
   Complete := True;
   return Result;
exception
   when Swallowed : others =>
      if Ada.Text_IO.Is_Open (File) then
         Ada.Text_IO.Close (File);
      end if;
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      Complete := False;
      return Result;
end Remembered_Volume_Trashes;
