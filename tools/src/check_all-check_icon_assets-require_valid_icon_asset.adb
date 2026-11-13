separate (Check_All.Check_Icon_Assets)
   procedure Require_Valid_Icon_Asset
     (Path          : String;
      Expected_Name : String)
   is
      Content    : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Saw_Header : Boolean := False;
      Saw_Name   : Boolean := False;
      Saw_Grid   : Boolean := False;
      Grid       : Natural := 0;
      Rectangles : Natural := 0;
      Triangles  : Natural := 0;

      procedure Check_Rectangle (Text : String) is
         X : Natural;
         Y : Natural;
         W : Natural;
         H : Natural;
      begin
         if not Saw_Grid then
            Fail_Icon (Path, "rectangle appears before grid declaration");
         elsif Field (Text, 6) /= "" then
            Fail_Icon (Path, "rectangle has too many fields");
         elsif not Try_Parse_Natural (Field (Text, 1), X)
           or else not Try_Parse_Natural (Field (Text, 2), Y)
           or else not Try_Parse_Natural (Field (Text, 3), W)
           or else not Try_Parse_Natural (Field (Text, 4), H)
         then
            Fail_Icon (Path, "rectangle has nonnumeric fields");
         elsif W = 0 or else H = 0 then
            Fail_Icon (Path, "rectangle must have positive dimensions");
         elsif X >= Grid or else Y >= Grid or else W > Grid - X or else H > Grid - Y then
            Fail_Icon (Path, "rectangle exceeds declared grid");
         elsif not Valid_Icon_Role (Field (Text, 5)) then
            Fail_Icon (Path, "rectangle uses an unknown role");
         end if;

         Rectangles := Rectangles + 1;
      end Check_Rectangle;

      procedure Check_Triangle (Text : String) is
         X1 : Natural;
         Y1 : Natural;
         X2 : Natural;
         Y2 : Natural;
         X3 : Natural;
         Y3 : Natural;
      begin
         if not Saw_Grid then
            Fail_Icon (Path, "triangle appears before grid declaration");
         elsif Field (Text, 8) /= "" then
            Fail_Icon (Path, "triangle has too many fields");
         elsif not Try_Parse_Natural (Field (Text, 1), X1)
           or else not Try_Parse_Natural (Field (Text, 2), Y1)
           or else not Try_Parse_Natural (Field (Text, 3), X2)
           or else not Try_Parse_Natural (Field (Text, 4), Y2)
           or else not Try_Parse_Natural (Field (Text, 5), X3)
           or else not Try_Parse_Natural (Field (Text, 6), Y3)
         then
            Fail_Icon (Path, "triangle has nonnumeric fields");
         elsif X1 > Grid or else Y1 > Grid or else X2 > Grid or else Y2 > Grid
           or else X3 > Grid or else Y3 > Grid
         then
            Fail_Icon (Path, "triangle exceeds declared grid");
         elsif not Valid_Icon_Role (Field (Text, 7)) then
            Fail_Icon (Path, "triangle uses an unknown role");
         end if;

         Triangles := Triangles + 1;
      end Check_Triangle;

      procedure Check_Line (Raw : String) is
         Line : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
      begin
         if Line = "" then
            return;
         elsif not Saw_Header then
            if Line /= "files-icon-v1" then
               Fail_Icon (Path, "missing files-icon-v1 header");
            end if;
            Saw_Header := True;
         elsif Starts_With (Line, "name=") then
            if Saw_Name then
               Fail_Icon (Path, "duplicate name declaration");
            elsif Value_After_Prefix (Line, "name=") /= Expected_Name then
               Fail_Icon (Path, "name does not match bundled asset id");
            end if;
            Saw_Name := True;
         elsif Starts_With (Line, "grid=") then
            if Saw_Grid then
               Fail_Icon (Path, "duplicate grid declaration");
            elsif not Try_Parse_Natural (Value_After_Prefix (Line, "grid="), Grid) or else Grid = 0 then
               Fail_Icon (Path, "grid must be a positive natural number");
            end if;
            Saw_Grid := True;
         elsif Starts_With (Line, "rect=") then
            Check_Rectangle (Value_After_Prefix (Line, "rect="));
         elsif Starts_With (Line, "tri=") then
            Check_Triangle (Value_After_Prefix (Line, "tri="));
         else
            Fail_Icon (Path, "unknown icon asset directive");
         end if;
      end Check_Line;
   begin
      if Content /= "" then
         declare
            Line_Start : Positive := Content'First;
         begin
            for Index in Content'Range loop
               if Content (Index) = ASCII.LF then
                  Check_Line (Content (Line_Start .. Index - 1));
                  Line_Start := Index + 1;
               end if;
            end loop;

            if Line_Start <= Content'Last then
               Check_Line (Content (Line_Start .. Content'Last));
            end if;
         end;
      end if;

      if not Saw_Header then
         Fail_Icon (Path, "missing files-icon-v1 header");
      elsif not Saw_Name then
         Fail_Icon (Path, "missing icon name declaration");
      elsif not Saw_Grid then
         Fail_Icon (Path, "missing icon grid declaration");
      elsif Rectangles = 0 and then Triangles = 0 then
         Fail_Icon (Path, "icon asset must contain at least one shape");
      end if;
   end Require_Valid_Icon_Asset;
