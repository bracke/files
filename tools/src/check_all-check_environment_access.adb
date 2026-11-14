separate (Check_All)
   procedure Check_Environment_Access is
      use Tokens;

      --  Whether a source's tokens read the environment: Ada's own, Hostkit's
      --  (which Files.Environment wraps), a C getenv bound by hand, GNAT's
      --  command-line environment, the C environment block imported whole
      --  (environ, _environ, __environ, _wenviron, macOS's _NSGetEnviron), or
      --  the Win32 calls. A name is read in code only, and a literal counts
      --  only as the symbol an import names: a comment or a message that
      --  mentions one reads nothing.
      function Reads_Environment (Toks : Token_List) return Boolean is
         --  Whether the word at Index is qualified by the word Prefix.
         function Qualified (Index : Positive; Prefix : String) return Boolean is
           (Index >= Toks.First_Index + 2
            and then Is_Symbol (Toks (Index - 1), ".")
            and then Is_Word (Toks (Index - 2), Prefix));

         --  Whether Text could be a linker symbol: name characters alone.
         function Is_Symbol_Name (Text : String) return Boolean is
           (Text'Length > 0 and then (for all C of Text => Is_Ada_Identifier_Char (C)));

         function Names_A_Reader (Text : String) return Boolean is
           (Contains (Text, "getenv") or else Contains (Text, "nsgetenviron"));
      begin
         for Index in Toks.First_Index .. Toks.Last_Index loop
            declare
               Text : constant String := To_String (Toks (Index).Text);
            begin
               case Toks (Index).Kind is
                  when Word =>
                     if Names_A_Reader (Text)
                       or else Contains (Text, "environment_value")
                       or else (Text = "environment_variables" and then Qualified (Index, "ada"))
                       or else (Starts_With (Text, "environment")
                                and then (Qualified (Index, "hostkit") or else Qualified (Index, "command_line")))
                     then
                        return True;
                     end if;
                  when Literal =>
                     if Is_Symbol_Name (Text)
                       and then (Text in "environ" | "_environ" | "__environ" | "_wenviron"
                                 or else Names_A_Reader (Text))
                     then
                        return True;
                     end if;
                  when Symbol =>
                     null;
               end case;
            end;
         end loop;
         return False;
      end Reads_Environment;

      --  The lint itself, on the imports it exists for (Reads) and on the
      --  mentions it must not take for one (Quiet): if it stopped seeing a
      --  read, the tree search below would pass on every source.
      type Sample_List is array (Positive range <>) of Unbounded_String;
      Reads : constant Sample_List :=
        [To_Unbounded_String ("V : constant String := Ada.Environment_Variables.Value (Name);"),
         To_Unbounded_String
           ("Env : System.Address" & ASCII.LF & "  with Import, Convention => C, External_Name => ""environ"";"),
         To_Unbounded_String
           ("pragma Import (C, Env, ""__environ"");"),
         To_Unbounded_String
           ("function NS_Get_Environ return System.Address" & ASCII.LF
            & "  with Import, Convention => C, External_Name => ""_NSGetEnviron"";"),
         To_Unbounded_String
           ("function Block return System.Address with Import, Convention => Stdcall,"
            & " External_Name => ""GetEnvironmentStringsW"";"),
         To_Unbounded_String
           ("V : constant String := Ada" & ASCII.LF & "  .Environment_Variables.Value (Name);")];
      Quiet : constant Sample_List :=
        [To_Unbounded_String ("--  Ada.Environment_Variables.Value (Name) is asked of Files.Environment only."),
         To_Unbounded_String ("Put_Line (""set it, as getenv or Ada.Environment_Variables.Value would read it"");"),
         To_Unbounded_String ("X : Natural := 0;  --  getenv (""environ"")")];
   begin
      for Index in Reads'Range loop
         if not Reads_Environment (Tokens_Of (To_String (Reads (Index)))) then
            Put_Line
              (Standard_Error,
               "check_all's Check_Environment_Access no longer sees the read in its sample" & Natural'Image (Index));
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end loop;
      for Index in Quiet'Range loop
         if Reads_Environment (Tokens_Of (To_String (Quiet (Index)))) then
            Put_Line
              (Standard_Error,
               "check_all's Check_Environment_Access takes the mention in its quiet sample" & Natural'Image (Index)
               & " for a read");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end loop;

      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories) loop
         declare
            Path : constant String := To_String (Item);
         begin
            if Ada.Directories.Simple_Name (Path) not in "files-environment.adb" | "files-environment.ads"
              and then Reads_Environment (Tokens_Of (To_String (Project_Tools.Text.Read_Text_File (Path))))
            then
               Put_Line (Standard_Error, Path & ": reads the environment directly; use Files.Environment");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
   end Check_Environment_Access;
