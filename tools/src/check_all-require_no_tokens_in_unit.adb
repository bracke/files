separate (Check_All)
   procedure Require_No_Tokens_In_Unit
     (Base_Path : String;
      Pattern   : String;
      Message   : String)
   is
      use Tokens;

      Wanted : constant Token_List := Tokens_Of (Pattern);
      Dir    : constant String := Ada.Directories.Containing_Directory (Base_Path);
      Stem   : constant String := Ada.Directories.Base_Name (Base_Path);

      procedure Scan (Path : String) is
         Toks : constant Token_List := Tokens_Of (Project_Tools.Files.Read_Raw_File (Path));
      begin
         if Wanted.Is_Empty then
            Report ("check_all: Require_No_Tokens_In_Unit was given a pattern with no tokens: " & Message);
            return;
         end if;
         for Start in Toks.First_Index .. Toks.Last_Index - Natural (Wanted.Length) + 1 loop
            declare
               Matches : Boolean := True;
            begin
               for Offset in 0 .. Natural (Wanted.Length) - 1 loop
                  declare
                     Have : constant Token := Toks (Start + Offset);
                     Want : constant Token := Wanted (Wanted.First_Index + Offset);
                  begin
                     if Have.Kind /= Want.Kind or else Have.Text /= Want.Text then
                        Matches := False;
                        exit;
                     end if;
                  end;
               end loop;
               if Matches then
                  Report (Path & ":" & Ada.Strings.Fixed.Trim (Toks (Start).Line'Image, Ada.Strings.Left)
                          & ": " & Message);
                  return;
               end if;
            end;
         end loop;
      end Scan;
   begin
      if Ada.Directories.Exists (Base_Path) then
         Scan (Base_Path);
      else
         Report (Base_Path & ": guarded unit no longer exists; point the guard at where the code went: " & Message);
         return;
      end if;
      if Ada.Directories.Extension (Base_Path) = "adb" then
         for Member of Project_Tools.Files.List_Tree (Dir, Stem & "-?*.adb", Generated_Directories) loop
            Scan (To_String (Member));
         end loop;
      end if;
   end Require_No_Tokens_In_Unit;
