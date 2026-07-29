separate (Files.File_System.Directory)
   function Pdf_Page_Count_Token (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Buffer : String (1 .. 4096);
      Last   : Natural;
      Count  : Natural := 0;

      function Page_Marker_At
        (Line : String;
         Pos  : Positive)
         return Boolean
      is
         Marker_Last : constant Natural := Pos + String'("/Type /Page")'Length - 1;
      begin
         if Marker_Last > Line'Last then
            return False;
         elsif Line (Pos .. Marker_Last) /= "/Type /Page" then
            return False;
         elsif Marker_Last = Line'Last then
            return True;
         end if;

         declare
            Next : constant Character := Line (Marker_Last + 1);
         begin
            return Next = ' '
              or else Next = ASCII.HT
              or else Next = ASCII.LF
              or else Next = ASCII.CR
              or else Next = ASCII.VT
              or else Next = ASCII.FF
              or else Next = '/'
              or else Next = '>'
              or else Next = '<'
              or else Next = ']'
              or else Next = '[';
         end;
      end Page_Marker_At;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Buffer, Last);
         if Last > 0 then
            declare
               Line : constant String := Buffer (1 .. Last);
               Pos  : Natural := Ada.Strings.Fixed.Index (Line, "/Type /Page");
            begin
               while Pos > 0 loop
                  if Page_Marker_At (Line, Pos) then
                     Count := Count + 1;
                  end if;
                  exit when Pos + 10 > Line'Last;
                  Pos := Ada.Strings.Fixed.Index (Line (Pos + 10 .. Line'Last), "/Type /Page");
               end loop;
            end;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      return "document.pdf.pages|" & Natural_Text (Count);
   exception
      when others =>
         Safe_Close (File);
         return "document.kind|pdf";
   end Pdf_Page_Count_Token;
