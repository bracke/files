separate (Files_Suite.Model)
   procedure Test_Bounded_Host_Text_Records
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path     : constant String := Join (Root, "bounded-host-lines");
      File     : Ada.Text_IO.File_Type;
      Line     : Unbounded_String;
      Complete : Boolean;
   begin
      Reset_Root;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, "123456789");
      Ada.Text_IO.Put_Line (File, "12345678");
      Ada.Text_IO.Put (File, "tail");
      Ada.Text_IO.Close (File);

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      Files.Bounded_Text_IO.Read_Line (File, 8, Line, Complete);
      Assert
        (not Complete and then Length (Line) = 0,
         "an oversized physical line is rejected without returning a prefix");

      Files.Bounded_Text_IO.Read_Line (File, 8, Line, Complete);
      Assert
        (Complete and then To_String (Line) = "12345678",
         "a line exactly at the bound is accepted after the oversized record");

      Files.Bounded_Text_IO.Read_Line (File, 8, Line, Complete);
      Assert
        (Complete and then To_String (Line) = "tail",
         "an unterminated final line below the bound is accepted");
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Test_Bounded_Host_Text_Records;
