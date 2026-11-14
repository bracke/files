separate (Check_All)
   package body Tokens is

      function Is_Blank (Char : Character) return Boolean is
        (Char in ' ' | ASCII.LF | ASCII.CR | ASCII.HT | ASCII.VT | ASCII.FF);

      --  The words after which a character literal may stand ("when 'a'"):
      --  after any other word, as after ")", a quote is an attribute's tick.
      function Precedes_Literal (Name : String) return Boolean is
        (Name = "when" or else Name = "return" or else Name = "in" or else Name = "and" or else Name = "or"
         or else Name = "xor" or else Name = "not" or else Name = "then" or else Name = "else" or else Name = "is"
         or else Name = "of" or else Name = "mod" or else Name = "rem" or else Name = "abs" or else Name = "range"
         or else Name = "do" or else Name = "loop" or else Name = "begin");

      function Tokens_Of (Source : String) return Token_List is
         Text   : constant String := Ada.Characters.Handling.To_Lower (Code_Of (Source));
         Result : Token_List;
         Index  : Positive := Text'First;

         procedure Add (Kind : Token_Kind; Item : String) is
         begin
            Result.Append (Token'(Kind => Kind, Text => To_Unbounded_String (Item)));
         end Add;

         function Ticks_Attribute return Boolean is
           (not Result.Is_Empty
            and then ((Result.Last_Element.Kind = Word
                       and then not Precedes_Literal (To_String (Result.Last_Element.Text)))
                      or else Is_Symbol (Result.Last_Element, ")")));
      begin
         while Index <= Text'Last loop
            if Is_Blank (Text (Index)) then
               Index := Index + 1;
            elsif Text (Index) = '"' then
               declare
                  Value : Unbounded_String;
                  Next  : Positive := Index + 1;
               begin
                  loop
                     exit when Next > Text'Last or else Text (Next) = ASCII.LF;
                     if Text (Next) /= '"' then
                        Append (Value, Text (Next));
                        Next := Next + 1;
                     elsif Next < Text'Last and then Text (Next + 1) = '"' then
                        Append (Value, '"');
                        Next := Next + 2;
                     else
                        Next := Next + 1;
                        exit;
                     end if;
                  end loop;
                  Add (Literal, To_String (Value));
                  Index := Next;
               end;
            elsif Text (Index) = '''
              and then Index + 2 <= Text'Last
              and then Text (Index + 2) = '''
              and then not Ticks_Attribute
            then
               Add (Literal, Text (Index + 1 .. Index + 1));
               Index := Index + 3;
            elsif Is_Ada_Identifier_Char (Text (Index)) then
               declare
                  Last : Positive := Index;
               begin
                  while Last < Text'Last and then Is_Ada_Identifier_Char (Text (Last + 1)) loop
                     Last := Last + 1;
                  end loop;
                  Add (Word, Text (Index .. Last));
                  Index := Last + 1;
               end;
            elsif Index < Text'Last
              and then (Text (Index .. Index + 1) = ":="
                        or else Text (Index .. Index + 1) = "=>"
                        or else Text (Index .. Index + 1) = "..")
            then
               Add (Symbol, Text (Index .. Index + 1));
               Index := Index + 2;
            else
               Add (Symbol, Text (Index .. Index));
               Index := Index + 1;
            end if;
         end loop;
         return Result;
      end Tokens_Of;
   end Tokens;
