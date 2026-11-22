separate (Check_All)
   procedure Check_Rendering_Model_Reads is
      --  A frame reads the model and changes none of it. Every subprogram
      --  in Files.Model or any of its children that takes the Window_Model
      --  "in out" is a mutator; the list is derived from the specs, so a new
      --  child or a new mutator is covered without editing this check.

      function Lower (Text : String) return String renames Ada.Characters.Handling.To_Lower;

      function Identifier_Char (C : Character) return Boolean is
        (C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_');

      --  "files-model-selection-type_ahead.ads" -> "files.model.selection.type_ahead"
      function Unit_Of (Path : String) return String is
         Simple : constant String := Ada.Directories.Simple_Name (Path);
         Stem   : String := Lower (Simple (Simple'First .. Simple'Last - 4));
      begin
         for C of Stem loop
            if C = '-' then
               C := '.';
            end if;
         end loop;
         return Stem;
      end Unit_Of;

      Mutators : Key_Sets.Set;

      --  Adds Unit.Name for every subprogram in the spec at Path whose
      --  parameter list has a Window_Model "in out".
      procedure Collect (Path : String) is
         Code : constant String :=
           Lower (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True));
         Unit : constant String := Unit_Of (Path);
         From : Positive := Code'First;
      begin
         loop
            declare
               P : constant Natural := Ada.Strings.Fixed.Index (Code (From .. Code'Last), "procedure ");
               F : constant Natural := Ada.Strings.Fixed.Index (Code (From .. Code'Last), "function ");
               At_Word : constant Natural :=
                 (if P = 0 then F elsif F = 0 then P else Natural'Min (P, F));
               Name_First : Positive;
               Name_Last  : Natural;
               Cursor     : Positive;
            begin
               exit when At_Word = 0;
               Name_First := Ada.Strings.Fixed.Index (Code (At_Word .. Code'Last), " ") + 1;
               while Name_First <= Code'Last and then Code (Name_First) = ' ' loop
                  Name_First := Name_First + 1;
               end loop;
               Name_Last := Name_First - 1;
               while Name_Last < Code'Last and then Identifier_Char (Code (Name_Last + 1)) loop
                  Name_Last := Name_Last + 1;
               end loop;
               Cursor := Name_Last + 1;
               while Cursor <= Code'Last and then Code (Cursor) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT loop
                  Cursor := Cursor + 1;
               end loop;
               if Name_Last >= Name_First and then Cursor <= Code'Last and then Code (Cursor) = '(' then
                  declare
                     Depth : Natural := 0;
                     Close : Positive := Cursor;
                  begin
                     for I in Cursor .. Code'Last loop
                        if Code (I) = '(' then
                           Depth := Depth + 1;
                        elsif Code (I) = ')' then
                           Depth := Depth - 1;
                           if Depth = 0 then
                              Close := I;
                              exit;
                           end if;
                        end if;
                     end loop;
                     declare
                        Params : String := Code (Cursor .. Close);
                     begin
                        for C of Params loop
                           if C in ASCII.LF | ASCII.CR | ASCII.HT then
                              C := ' ';
                           end if;
                        end loop;
                        --  "Model : in out Window_Model" (or the full name),
                        --  once runs of blanks are allowed for.
                        declare
                           Compact : Ada.Strings.Unbounded.Unbounded_String;
                        begin
                           for I in Params'Range loop
                              if not (Params (I) = ' ' and then I > Params'First and then Params (I - 1) = ' ') then
                                 Ada.Strings.Unbounded.Append (Compact, Params (I));
                              end if;
                           end loop;
                           declare
                              Text : constant String := Ada.Strings.Unbounded.To_String (Compact);
                           begin
                              if Ada.Strings.Fixed.Index (Text, "in out window_model") > 0
                                or else Ada.Strings.Fixed.Index (Text, "in out files.model.window_model") > 0
                              then
                                 Mutators.Include (Unit & "." & Code (Name_First .. Name_Last));
                              end if;
                           end;
                        end;
                     end;
                     From := Close;
                  end;
               else
                  From := Natural'Max (Name_Last, At_Word) + 1;
               end if;
               exit when From > Code'Last;
            end;
         end loop;
      end Collect;

      --  Every dotted name in the rendering file at Path that is a mutator.
      procedure Check (Path : String) is
         Code : constant String :=
           Lower (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True));
         From : Positive := Code'First;
      begin
         loop
            declare
               At_Name : constant Natural := Ada.Strings.Fixed.Index (Code (From .. Code'Last), "files.model.");
               Last    : Natural;
            begin
               exit when At_Name = 0;
               Last := At_Name - 1;
               while Last < Code'Last and then (Identifier_Char (Code (Last + 1)) or else Code (Last + 1) = '.') loop
                  Last := Last + 1;
               end loop;
               declare
                  Name : constant String := Code (At_Name .. Last);
               begin
                  if (At_Name = Code'First or else not Identifier_Char (Code (At_Name - 1)))
                    and then Mutators.Contains (Name)
                  then
                     Report (Path & ": a frame must not change the model (" & Name & ")");
                  end if;
               end;
               From := Last + 1;
               exit when From > Code'Last;
            end;
         end loop;
      end Check;
   begin
      for Pattern of String_List'[To_Unbounded_String ("files-model.ads"), To_Unbounded_String ("files-model-*.ads")]
      loop
         for Item of Project_Tools.Files.List_Tree (Root & "/src", To_String (Pattern), Generated_Directories) loop
            Collect (To_String (Item));
         end loop;
      end loop;
      --  An empty list would make the guard pass vacuously.
      if Natural (Mutators.Length) < 20 then
         Report ("Check_Rendering_Model_Reads found only" & Natural'Image (Natural (Mutators.Length))
                 & " model mutators; the spec scan is broken");
      end if;
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "files-rendering*.ad?", Generated_Directories) loop
         Check (To_String (Item));
      end loop;
   end Check_Rendering_Model_Reads;
