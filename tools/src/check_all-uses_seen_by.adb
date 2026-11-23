separate (Check_All)
   function Uses_Seen_By (Path : String) return Tokens.Token_List is
      use Tokens;
      Result    : Token_List;
      Directory : constant String := Ada.Directories.Containing_Directory (Path);
      Stem      : constant String := Ada.Directories.Base_Name (Path);
      Is_Body   : constant Boolean := Ada.Strings.Fixed.Tail (Path, 4) = ".adb";

      procedure Take_Uses (Source : String) is
         Source_Toks : constant Token_List := Tokens_Of (Project_Tools.Files.Read_Raw_File (Source));
         Index       : Natural := Source_Toks.First_Index;
      begin
         while Index <= Source_Toks.Last_Index loop
            if Is_Word (Source_Toks (Index), "use") then
               while Index <= Source_Toks.Last_Index loop
                  Result.Append (Source_Toks (Index));
                  exit when Is_Symbol (Source_Toks (Index), ";");
                  Index := Index + 1;
               end loop;
            end if;
            Index := Index + 1;
         end loop;
      end Take_Uses;
   begin
      for Index in Stem'Range loop
         if Stem (Index) = '-' or else Index = Stem'Last then
            declare
               Ancestor : constant String := Stem (Stem'First .. (if Stem (Index) = '-' then Index - 1 else Index));
               Spec     : constant String := Directory & "/" & Ancestor & ".ads";
               Body_Of  : constant String := Directory & "/" & Ancestor & ".adb";
            begin
               if Ada.Directories.Exists (Spec) and then (Is_Body or else Ancestor /= Stem) then
                  Take_Uses (Spec);
               end if;
               if Is_Body
                 and then Ancestor /= Stem
                 and then Ada.Directories.Exists (Body_Of)
                 and then Is_Subunit_Of (Path, Unit_Of_File (Body_Of))
               then
                  Take_Uses (Body_Of);
               end if;
            end;
         end if;
      end loop;
      return Result;
   end Uses_Seen_By;
