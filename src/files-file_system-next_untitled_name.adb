separate (Files.File_System)
function Next_Untitled_Name
  (Directory_Path : String)
   return String
is
   Candidate : Unbounded_String := To_Unbounded_String ("untitled.txt");
   Counter   : Positive := 2;

   function Counter_Text return String is (Files.Types.Natural_Text (Counter));
begin
   while Files.Fs_Primitives.Entry_Exists (Join_Path (Directory_Path, To_String (Candidate)))
   loop
      Candidate := To_Unbounded_String ("untitled " & Counter_Text & ".txt");
      exit when Counter = Positive'Last;
      Counter := Counter + 1;
   end loop;

   return To_String (Candidate);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return "untitled.txt";
end Next_Untitled_Name;
