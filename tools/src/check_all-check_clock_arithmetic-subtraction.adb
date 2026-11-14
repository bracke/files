separate (Check_All.Check_Clock_Arithmetic)
   function Subtraction
     (Toks       : Token_List;
      Time_Names : Name_Sets.Set;
      Timing     : Boolean)
      return String
   is
      First : constant Positive := Toks.First_Index;
      Last  : constant Natural := Toks.Last_Index;

      function Word_At (Index : Integer; Text : String) return Boolean is
        (Index in First .. Last and then Is_Word (Toks (Index), Text));

      function Symbol_At (Index : Integer; Text : String) return Boolean is
        (Index in First .. Last and then Is_Symbol (Toks (Index), Text));

      --  Whether the tokens from Index on spell the dotted name Parts (words
      --  joined by dots, as "ada.real_time.time").
      function Name_At (Index : Positive; Parts : String) return Boolean is
         Dot : constant Natural := Ada.Strings.Fixed.Index (Parts, ".");
      begin
         if Dot = 0 then
            return Word_At (Index, Parts);
         end if;
         return Word_At (Index, Parts (Parts'First .. Dot - 1))
           and then Symbol_At (Index + 1, ".")
           and then Name_At (Index + 2, Parts (Dot + 1 .. Parts'Last));
      end Name_At;

      --  The dotted name from Index on, as text ("ada.calendar"), and where
      --  it ends.
      procedure Dotted_Name (Index : Positive; Name : out Unbounded_String; Stop : out Natural) is
      begin
         Name := Null_Unbounded_String;
         Stop := Index - 1;
         if Index <= Last and then Toks (Index).Kind = Word then
            Name := Toks (Index).Text;
            Stop := Index;
            while Symbol_At (Stop + 1, ".") and then Stop + 2 <= Last and then Toks (Stop + 2).Kind = Word loop
               Append (Name, "." & To_String (Toks (Stop + 2).Text));
               Stop := Stop + 2;
            end loop;
         end if;
      end Dotted_Name;

      --  Whether the "use" at Index names a clock package, alone or in a
      --  list ("use Ada.Calendar, Other;"); a use type clause does not.
      function Uses_A_Clock_Package (Index : Positive) return Boolean is
         Next : Positive := Index + 1;
         Name : Unbounded_String;
         Stop : Natural;
      begin
         if Word_At (Next, "type") or else Word_At (Next, "all") then
            return False;
         end if;
         loop
            Dotted_Name (Next, Name, Stop);
            exit when Stop < Next;
            if To_String (Name) in "ada.real_time" | "ada.calendar" then
               return True;
            end if;
            exit when not Symbol_At (Stop + 1, ",");
            Next := Stop + 2;
         end loop;
         return False;
      end Uses_A_Clock_Package;
   begin
      for Index in First .. Last loop
         --  Clock, or Clock (), then a minus.
         if Word_At (Index, "clock")
           and then (Symbol_At (Index + 1, "-")
                     or else (Symbol_At (Index + 1, "(") and then Symbol_At (Index + 2, ")")
                              and then Symbol_At (Index + 3, "-")))
         then
            return "subtracting from the clock";
         end if;
      end loop;
      for Index in First .. Last loop
         if Symbol_At (Index, "-") and then Name_At (Index + 1, "ada.real_time.time_first") then
            return "subtracting Time_First";
         end if;
      end loop;
      --  The operator spelled out does the same, and Files.Timing is where
      --  it is done once, guarded.
      if not Timing then
         for Index in First .. Last loop
            if (Name_At (Index, "ada.real_time") or else Name_At (Index, "ada.calendar"))
              and then Index + 4 <= Last
              and then Symbol_At (Index + 3, ".")
              and then Toks (Index + 4).Kind = Literal
              and then To_String (Toks (Index + 4).Text) = "-"
            then
               return "subtracting times with the operator named";
            end if;
         end loop;
      end if;
      --  A use clause lets a time be declared as plain Time, and a subtype
      --  gives it another name: either hides it from the name check below.
      for Index in First .. Last loop
         if Word_At (Index, "use") and then Uses_A_Clock_Package (Index) then
            return "a use clause for a clock package (use type is fine)";
         elsif Word_At (Index, "is")
           and then (Name_At (Index + 1, "ada.real_time.time") or else Name_At (Index + 1, "ada.calendar.time"))
           and then Symbol_At (Index + 6, ";")
         then
            return "a renamed time type";
         end if;
      end loop;
      --  Now - Last, where Last is a time some variable or field starts
      --  at: the right operand is a name declared as a time in the file's
      --  unit family (its last component, for a field). Binary only: a name,
      --  a literal or a parenthesis before the minus.
      for Index in First .. Last loop
         if Symbol_At (Index, "-")
           and then Index > First
           and then (Toks (Index - 1).Kind = Word or else Symbol_At (Index - 1, ")"))
         then
            declare
               Operand : Unbounded_String;
               Stop    : Natural;
            begin
               Dotted_Name (Index + 1, Operand, Stop);
               if Stop > Index and then Time_Names.Contains (To_String (Toks (Stop).Text)) then
                  return "subtracting the time " & To_String (Operand);
               end if;
            end;
         end if;
      end loop;
      return "";
   end Subtraction;
