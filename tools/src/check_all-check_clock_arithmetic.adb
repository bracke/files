separate (Check_All)
   procedure Check_Clock_Arithmetic is
      use Tokens;

      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");

      --  What a source subtracts that can overflow, or "" when nothing does.
      --  Read from its tokens, so a comment or a message that spells a
      --  subtraction is none.
      --  @param Toks The source's tokens.
      --  @param Time_Names Every name declared as a time in its unit family.
      --  @param Timing Whether it is Files.Timing, which may name the operator.
      --  @return What it subtracts, as a refusal names it, or "".
      function Subtraction
        (Toks       : Token_List;
         Time_Names : Name_Sets.Set;
         Timing     : Boolean)
         return String
      is separate;

      --  Every name declared with a time type: "Name : [aliased] [constant]
      --  Ada.Real_Time.Time" or "... Ada.Calendar.Time".
      procedure Collect (Toks : Token_List; Into : in out Name_Sets.Set) is separate;

      --  What a sample subtracts, its time names collected from itself.
      function Sample_Subtraction (Text : String) return String is
         Toks  : constant Token_List := Tokens_Of (Text);
         Names : Name_Sets.Set;
      begin
         Collect (Toks, Names);
         return Subtraction (Toks, Names, Timing => False);
      end Sample_Subtraction;

      procedure Fail (Message : String) is
      begin
         Put_Line (Standard_Error, Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      --  The lint itself, on the shapes it exists for (Refused) and on the
      --  mentions it must not take for one (Quiet): if it stopped seeing a
      --  subtraction, the tree search below would pass on every source.
      LF : constant Character := ASCII.LF;
      type Sample_List is array (Positive range <>) of Unbounded_String;
      Refused : constant Sample_List :=
        [To_Unbounded_String ("D : constant Duration := To_Duration (Clock - Since);"),
         To_Unbounded_String ("D := Ada.Real_Time.Clock ()" & LF & "  - Since;"),
         To_Unbounded_String ("Since : Ada.Real_Time.Time;" & LF & "D := Now - Since;"),
         To_Unbounded_String ("Last : aliased constant Ada.Calendar.Time := Start;" & LF & "D := Now - Self.Last;"),
         To_Unbounded_String ("D := Now - Ada.Real_Time.Time_First;"),
         To_Unbounded_String ("D := Ada.Real_Time.""-"" (Now, Since);"),
         To_Unbounded_String ("use Other, Ada.Calendar;"),
         To_Unbounded_String ("subtype Moment is Ada.Calendar.Time;")];
      Quiet : constant Sample_List :=
        [To_Unbounded_String ("X : Natural := 0;  --  Clock - Since overflows"),
         To_Unbounded_String ("Put_Line (""Clock - Since"");"),
         To_Unbounded_String ("Since : Ada.Real_Time.Time;" & LF & "Put_Line (""Now - Since"");"),
         To_Unbounded_String ("Since : Ada.Real_Time.Time;" & LF & "Ready := Clock >= Since + Span;"),
         To_Unbounded_String ("Put_Line (""use Ada.Calendar;"");"),
         To_Unbounded_String ("use type Ada.Real_Time.Time;")];

      procedure Refuse (Path, What : String) is
      begin
         Fail (Path & ": " & What & " can overflow (Time_First is a common start); use Files.Timing.Elapsed");
      end Refuse;
   begin
      for Index in Refused'Range loop
         if Sample_Subtraction (To_String (Refused (Index))) = "" then
            Fail ("check_all's Check_Clock_Arithmetic no longer sees the subtraction in its sample"
                  & Natural'Image (Index));
         end if;
      end loop;
      for Index in Quiet'Range loop
         if Sample_Subtraction (To_String (Quiet (Index))) /= "" then
            Fail ("check_all's Check_Clock_Arithmetic takes the mention in its quiet sample" & Natural'Image (Index)
                  & " for a subtraction");
         end if;
      end loop;

      declare
         type Token_Lists is array (Positive range <>) of Token_List;
         Sources : constant Project_Tools.Files.Path_List :=
           Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories);
         Toks    : Token_Lists (Sources'Range);

         --  Whether Other_Stem is of the unit family of Stem: the same, or a
         --  dash-prefix of it (a parent of a child or a subunit).
         function Family (Stem, Other_Stem : String) return Boolean is
           (Other_Stem = Stem
            or else (Other_Stem'Length < Stem'Length
                     and then Stem (Stem'First .. Stem'First + Other_Stem'Length - 1) = Other_Stem
                     and then Stem (Stem'First + Other_Stem'Length) = '-'));
      begin
         for Index in Sources'Range loop
            Toks (Index) := Tokens_Of (To_String (Project_Tools.Text.Read_Text_File (To_String (Sources (Index)))));
         end loop;
         --  The times a file can name: its own, and those of the specs and
         --  bodies of its unit family.
         for Index in Sources'Range loop
            declare
               Path  : constant String := To_String (Sources (Index));
               Stem  : constant String := Ada.Directories.Base_Name (Path);
               Names : Name_Sets.Set;
            begin
               for Other in Sources'Range loop
                  if Family (Stem, Ada.Directories.Base_Name (To_String (Sources (Other)))) then
                     Collect (Toks (Other), Names);
                  end if;
               end loop;
               declare
                  What : constant String :=
                    Subtraction
                      (Toks (Index), Names,
                       Timing => Ada.Directories.Simple_Name (Path) in "files-timing.adb" | "files-timing.ads");
               begin
                  if What /= "" then
                     Refuse (Path, What);
                  end if;
               end;
            end;
         end loop;
      end;
   end Check_Clock_Arithmetic;
