separate (Files.File_System)
   function Next_Untitled_Name
     (Directory_Path : String)
      return String
   is
      Candidate : Unbounded_String := To_Unbounded_String ("untitled.txt");
      Counter   : Positive := 2;

      function Counter_Text return String is
         Image : constant String := Positive'Image (Counter);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Counter_Text;
   begin
      while Ada.Directories.Exists (Join_Path (Directory_Path, To_String (Candidate))) loop
         Candidate := To_Unbounded_String ("untitled " & Counter_Text & ".txt");
         exit when Counter = Positive'Last;
         Counter := Counter + 1;
      end loop;

      return To_String (Candidate);
   exception
      when others =>
         return "untitled.txt";
   end Next_Untitled_Name;
