separate (Check_All.Check_Clock_Arithmetic)
   procedure Collect (Toks : Token_List; Into : in out Name_Sets.Set) is
      First : constant Positive := Toks.First_Index;
      Last  : constant Natural := Toks.Last_Index;

      function Word_At (Index : Integer; Text : String) return Boolean is
        (Index in First .. Last and then Is_Word (Toks (Index), Text));

      function Symbol_At (Index : Integer; Text : String) return Boolean is
        (Index in First .. Last and then Is_Symbol (Toks (Index), Text));

      --  The words that may stand between a declaration's colon and its
      --  type: "Name : aliased constant", "Name : in out", "Name : not null
      --  access constant".
      function Is_Qualifier (Index : Integer) return Boolean is
        (for some Qualifier of String_List'
           [To_Unbounded_String ("aliased"), To_Unbounded_String ("constant"), To_Unbounded_String ("in"),
            To_Unbounded_String ("out"), To_Unbounded_String ("not"), To_Unbounded_String ("null"),
            To_Unbounded_String ("access")] =>
            Word_At (Index, To_String (Qualifier)));
   begin
      for Index in First .. Last loop
         --  The whole type name, Ada.Real_Time.Time or Ada.Calendar.Time,
         --  not Time_Span or Time_First, nor a prefix of a longer name.
         if Word_At (Index, "ada")
           and then Symbol_At (Index + 1, ".")
           and then (Word_At (Index + 2, "real_time") or else Word_At (Index + 2, "calendar"))
           and then Symbol_At (Index + 3, ".")
           and then Word_At (Index + 4, "time")
           and then not Symbol_At (Index + 5, ".")
         then
            declare
               Colon : Integer := Index - 1;
            begin
               while Is_Qualifier (Colon) loop
                  Colon := Colon - 1;
               end loop;
               if Symbol_At (Colon, ":") and then Colon - 1 >= First and then Toks (Colon - 1).Kind = Word then
                  Into.Include (To_String (Toks (Colon - 1).Text));
               end if;
            end;
         end if;
      end loop;
   end Collect;
