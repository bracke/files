separate (Check_All.Check_Clock_Arithmetic)
   procedure Check (Path : String) is
      Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
      From : Positive := Code'First;
      At_Clock : Natural;
   begin
      loop
         At_Clock := Ada.Strings.Fixed.Index (Code (From .. Code'Last), "Clock");
         exit when At_Clock = 0;
         declare
            Next : Positive := At_Clock + 5;
         begin
            --  Clock, Clock (), then blanks, then a lone minus.
            if Next + 1 <= Code'Last and then Code (Next .. Next + 1) = "()" then
               Next := Next + 2;
            end if;
            while Next <= Code'Last and then Code (Next) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT loop
               Next := Next + 1;
            end loop;
            if Next <= Code'Last and then Code (Next) = '-'
              and then (At_Clock = Code'First
                        or else Code (At_Clock - 1) not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_')
            then
               Refuse (Path, "subtracting from the clock");
            end if;
            exit when At_Clock + 5 > Code'Last;
            From := At_Clock + 5;
         end;
      end loop;
      if Ada.Strings.Fixed.Index (Code, "- Ada.Real_Time.Time_First") > 0
        or else Ada.Strings.Fixed.Index (Code, "-Ada.Real_Time.Time_First") > 0
      then
         Refuse (Path, "subtracting Time_First");
      end if;
      --  The operator spelled out does the same, and Files.Timing is where
      --  it is done once, guarded.
      if Ada.Directories.Simple_Name (Path) not in "files-timing.adb" | "files-timing.ads"
        and then (Ada.Strings.Fixed.Index (Code, "Ada.Real_Time.""-""") > 0
                  or else Ada.Strings.Fixed.Index (Code, "Ada.Calendar.""-""") > 0)
      then
         Refuse (Path, "subtracting times with the operator named");
      end if;
      --  A use clause lets a time be declared as plain Time, and a subtype
      --  gives it another name: either hides it from the name check below.
      declare
         Lower : constant String := Ada.Characters.Handling.To_Lower (Code);

         --  Whether a use clause (not use type) names a clock package,
         --  alone or in a list: "use Ada.Calendar, Other;" counts too.
         function Uses_A_Clock_Package return Boolean is
            From   : Positive := Lower'First;
            At_Use : Natural;
         begin
            loop
               At_Use := Ada.Strings.Fixed.Index (Lower (From .. Lower'Last), "use ");
               exit when At_Use = 0;
               if At_Use = Lower'First
                 or else Lower (At_Use - 1) not in 'a' .. 'z' | '0' .. '9' | '_' | '.'
               then
                  declare
                     Stop    : constant Natural :=
                       Ada.Strings.Fixed.Index (Lower (At_Use .. Lower'Last), ";");
                     Clause  : constant String :=
                       (if Stop = 0 then "" else Lower (At_Use + 4 .. Stop - 1));
                     Item_At : Positive := Clause'First;
                     Comma   : Natural;
                  begin
                     if Clause'Length > 0
                       and then Ada.Strings.Fixed.Trim (Clause, Ada.Strings.Both)'Length > 0
                       and then Ada.Strings.Fixed.Head (Ada.Strings.Fixed.Trim (Clause, Ada.Strings.Left), 5)
                                  /= "type "
                       and then Ada.Strings.Fixed.Head (Ada.Strings.Fixed.Trim (Clause, Ada.Strings.Left), 4)
                                  /= "all "
                     then
                        loop
                           Comma := Ada.Strings.Fixed.Index (Clause (Item_At .. Clause'Last), ",");
                           declare
                              Name : constant String :=
                                Ada.Strings.Fixed.Trim
                                  (Ada.Strings.Fixed.Translate
                                     (Clause (Item_At .. (if Comma = 0 then Clause'Last else Comma - 1)),
                                      Ada.Strings.Maps.To_Mapping (ASCII.LF & ASCII.CR & ASCII.HT, "   ")),
                                   Ada.Strings.Both);
                           begin
                              if Name in "ada.real_time" | "ada.calendar" then
                                 return True;
                              end if;
                           end;
                           exit when Comma = 0;
                           Item_At := Comma + 1;
                        end loop;
                     end if;
                  end;
               end if;
               exit when At_Use + 4 > Lower'Last;
               From := At_Use + 4;
            end loop;
            return False;
         end Uses_A_Clock_Package;
      begin
         if Uses_A_Clock_Package then
            Refuse (Path, "a use clause for a clock package (use type is fine)");
         elsif Ada.Strings.Fixed.Index (Lower, " is ada.real_time.time;") > 0
           or else Ada.Strings.Fixed.Index (Lower, " is ada.calendar.time;") > 0
         then
            Refuse (Path, "a renamed time type");
         end if;
      end;
      --  Now - Last, where Last is a time some variable or field starts
      --  at: the right operand is a name declared as a time in the file's
      --  unit family (its last component, for a field).
      declare
         Index : Natural := Ada.Strings.Fixed.Index (Code, "-");
      begin
         while Index /= 0 loop
            declare
               First  : Positive := Index + 1;
               Last   : Natural;
               Before : Integer;
            begin
               while First <= Code'Last and then Code (First) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT loop
                  First := First + 1;
               end loop;
               Last := First - 1;
               while Last < Code'Last
                 and then Code (Last + 1) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '.'
               loop
                  Last := Last + 1;
               end loop;
               --  Binary only: a name, a literal or a parenthesis before it.
               Before := Index - 1;
               while Before >= Code'First and then Code (Before) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT loop
                  Before := Before - 1;
               end loop;
               if Last >= First
                 and then Before >= Code'First
                 and then Code (Before) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | ')'
               then
                  declare
                     Operand : constant String := Code (First .. Last);
                     Dot     : constant Natural := Ada.Strings.Fixed.Index (Operand, ".", Ada.Strings.Backward);
                     Name    : constant String :=
                       (if Dot = 0 then Operand else Operand (Dot + 1 .. Operand'Last));
                  begin
                     if Name /= "" and then Time_Names.Contains (Ada.Characters.Handling.To_Lower (Name)) then
                        Refuse (Path, "subtracting the time " & Operand);
                     end if;
                  end;
               end if;
            end;
            exit when Index = Code'Last;
            Index := Ada.Strings.Fixed.Index (Code (Index + 1 .. Code'Last), "-");
         end loop;
      end;
   end Check;
