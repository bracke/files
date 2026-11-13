separate (Check_All)
   procedure Check_Ada_Keyword_Identifier_In_File (Path : String) is
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;

      procedure Fail (Name : String) is
      begin
         Put_Line
           (Standard_Error,
            Path & ":" & Natural'Image (Line_Number)
            & ": Ada reserved word used as identifier: " & Name);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      procedure Check_Name (Name : String) is
      begin
         if Name /= "" and then Is_Ada_Reserved_Word (Name) then
            Fail (Name);
         end if;
      end Check_Name;

      procedure Check_Line (Raw : String) is
         Line     : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         Colon    : constant Natural := Ada.Strings.Fixed.Index (Line, ":");
         Assign   : constant Natural := Ada.Strings.Fixed.Index (Line, "=>");
      begin
         if Line = "" or else Starts_With (Line, "--") then
            return;
         elsif Starts_With (Line, "overriding function ") then
            Check_Name (Token_After (Line, "overriding function "));
         elsif Starts_With (Line, "overriding procedure ") then
            Check_Name (Token_After (Line, "overriding procedure "));
         elsif Starts_With (Line, "function ") then
            Check_Name (Token_After (Line, "function "));
         elsif Starts_With (Line, "procedure ") then
            Check_Name (Token_After (Line, "procedure "));
         elsif Starts_With (Line, "type ") then
            Check_Name (Token_After (Line, "type "));
         elsif Starts_With (Line, "subtype ") then
            Check_Name (Token_After (Line, "subtype "));
         elsif Starts_With (Line, "package body ") then
            null;
         elsif Starts_With (Line, "package ") then
            Check_Name (Token_After (Line, "package "));
         elsif Colon > 0 and then (Assign = 0 or else Colon < Assign) then
            declare
               Name : constant String :=
                 Ada.Strings.Fixed.Trim (Line (Line'First .. Colon - 1), Ada.Strings.Both);
            begin
               if Is_Single_Identifier (Name) then
                  Check_Name (Name);
               end if;
            end;
         end if;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Ada_Keyword_Identifier_In_File;
