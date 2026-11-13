separate (Check_All)
   procedure Check_Visible_Cache_Invalidation is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;

      Writes : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("model.items :="),
         To_Unbounded_String ("model.items.clear"),
         To_Unbounded_String ("model.items.append"),
         To_Unbounded_String ("model.items.prepend"),
         To_Unbounded_String ("model.items.delete"),
         To_Unbounded_String ("model.items.insert"),
         To_Unbounded_String ("model.items.move"),
         To_Unbounded_String ("model.items.swap"),
         To_Unbounded_String ("model.items.set_length"),
         To_Unbounded_String ("model.items.reverse_elements"),
         To_Unbounded_String ("sort_items (model.items"),
         To_Unbounded_String ("filter_value :="),
         To_Unbounded_String ("search_results_active :=")];

      --  Text lowered, with every run of blanks and line ends one space.
      function Collapsed (Text : String) return String is
         Result : Unbounded_String;
         Blank  : Boolean := False;
      begin
         for C of Ada.Characters.Handling.To_Lower (Text) loop
            if C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
               Blank := True;
            else
               if Blank and then Length (Result) > 0 then
                  Append (Result, ' ');
               end if;
               Blank := False;
               Append (Result, C);
            end if;
         end loop;
         return To_String (Result);
      end Collapsed;

      procedure Check_File (Path : String) is
         Code    : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
         Indent  : constant Natural := (if Ada.Strings.Fixed.Index (Code, "separate (") > 0 then 0 else 3);
         Pad     : constant String (1 .. Indent) := [others => ' '];
         Name    : Unbounded_String;
         Body_Of : Unbounded_String;

         --  The name a top-level subprogram header at Indent declares, or "".
         function Header_Name (Line : String) return String is
         begin
            for Word in 1 .. 2 loop
               declare
                  Lead : constant String := Pad & (if Word = 1 then "procedure " else "function ");
               begin
                  if Line'Length > Lead'Length and then Line (Line'First .. Line'First + Lead'Length - 1) = Lead then
                     declare
                        Rest : constant String := Line (Line'First + Lead'Length .. Line'Last);
                        Stop : Natural := Rest'First;
                     begin
                        while Stop <= Rest'Last and then Rest (Stop) not in ' ' | '(' | ';' loop
                           Stop := Stop + 1;
                        end loop;
                        return Rest (Rest'First .. Stop - 1);
                     end;
                  end if;
               end;
            end loop;
            return "";
         end Header_Name;

         --  Judge the subprogram read so far, and forget it.
         procedure Judge is
            Text : constant String := Collapsed (To_String (Body_Of));
         begin
            if Length (Name) > 0 and then Ada.Strings.Fixed.Index (Text, "invalidate_visible") = 0 then
               for Write of Writes loop
                  if Ada.Strings.Fixed.Index (Text, To_String (Write)) > 0 then
                     Put_Line
                       (Standard_Error,
                        Path & ": " & To_String (Name) & " writes '" & To_String (Write)
                        & "' without Invalidate_Visible: the visible-row cache would serve old rows");
                     Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                     raise Program_Error;
                  end if;
               end loop;
            end if;
            Name := Null_Unbounded_String;
            Body_Of := Null_Unbounded_String;
         end Judge;

         procedure Visit (Line : String) is
         begin
            --  An expression function (or a declaration) has no "end Name;":
            --  the next header at the same level closes it, so what follows
            --  one is never left unchecked.
            if Header_Name (Line) /= "" then
               Judge;
               Name := To_Unbounded_String (Header_Name (Line));
               Body_Of := To_Unbounded_String (Line);
               return;
            elsif Length (Name) = 0 then
               return;
            end if;
            Append (Body_Of, ASCII.LF & Line);
            if Line = Pad & "end " & To_String (Name) & ";" then
               Judge;
            end if;
         end Visit;

         First : Positive := Code'First;
      begin
         for Index in Code'Range loop
            if Code (Index) = ASCII.LF then
               Visit (Code (First .. Index - 1));
               First := Index + 1;
            end if;
         end loop;
         if First <= Code'Last then
            Visit (Code (First .. Code'Last));
         end if;
         Judge;
      end Check_File;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "files-model*.adb", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         Check_File (Ada.Directories.Full_Name (Item));
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Visible_Cache_Invalidation;
