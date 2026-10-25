separate (Files_Suite.Settings)
   --  Every scalar setting in the descriptor table round-trips: a model holding a
   --  non-default value writes it under its key, parses back to the same value,
   --  and (for a pane-edited setting) survives Make_Draft and Apply_Draft. A
   --  setting the pane does not edit keeps the live value through Apply_Draft.
   --  Iterating the enumeration covers a newly added setting automatically; one
   --  whose values none of the samples below fit fails the first assertion,
   --  asking for a sample to be added.
   procedure Test_Scalar_Settings_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Settings.Scalar_Setting;

      Samples : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("true"),
         To_Unbounded_String ("false"),
         To_Unbounded_String ("details"),
         To_Unbounded_String ("size"),
         To_Unbounded_String ("high_contrast"),
         To_Unbounded_String ("files-high-contrast"),
         To_Unbounded_String ("24"),
         To_Unbounded_String ("label"),
         To_Unbounded_String ("name,permissions,created,filetype,size,modified"),
         To_Unbounded_String ("800")];

      Defaults : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      for Setting in Files.Settings.Scalar_Setting loop
         declare
            Key          : constant String := Files.Settings.Scalar_Key (Setting);
            Default_Text : constant String := Files.Settings.Scalar_Text (Defaults, Setting);
            Changed      : Files.Settings.Settings_Model := Defaults;
            Found        : Boolean := False;
         begin
            for Sample of Samples loop
               declare
                  Candidate : Files.Settings.Settings_Model := Defaults;
                  Error     : Unbounded_String;
               begin
                  Files.Settings.Set_Scalar (Candidate, Setting, To_String (Sample), Error);
                  if not Found
                    and then Length (Error) = 0
                    and then Files.Settings.Scalar_Text (Candidate, Setting) /= Default_Text
                  then
                     Changed := Candidate;
                     Found := True;
                  end if;
               end;
            end loop;
            Assert (Found, Key & " accepts one of the sample values as a non-default value");

            declare
               Value  : constant String := Files.Settings.Scalar_Text (Changed, Setting);
               Text   : constant String := Files.Settings.To_Text (Changed);
               Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Text);
            begin
               Assert
                 (Ada.Strings.Fixed.Index (Text, ASCII.LF & Key & " = ") > 0,
                  Key & " is written under its key when it differs from the default");
               Assert (Parsed.Success, Key & " text with a non-default value parses");
               Files_Suite.Support.Assert_Equal
                 (Files.Settings.Scalar_Text (Parsed.Settings, Setting),
                  Value,
                  Key & " parses back to the written value");

               declare
                  Draft   : constant Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Changed);
                  Applied : constant Files.Settings.Settings_Parse_Result :=
                    Files.Settings.Apply_Draft (Defaults, Draft);
               begin
                  Assert (Applied.Success, Key & " draft applies");
                  if Files.Settings.Is_Pane_Setting (Setting) then
                     Files_Suite.Support.Assert_Equal
                       (To_String (Draft.Scalars (Setting)),
                        Value,
                        Key & " draft slot holds the value text");
                     Files_Suite.Support.Assert_Equal
                       (Files.Settings.Scalar_Text (Applied.Settings, Setting),
                        Value,
                        Key & " survives the draft round trip");
                  else
                     Files_Suite.Support.Assert_Equal
                       (To_String (Draft.Scalars (Setting)),
                        "",
                        Key & " has no draft slot");
                     Files_Suite.Support.Assert_Equal
                       (Files.Settings.Scalar_Text (Applied.Settings, Setting),
                        Default_Text,
                        Key & " keeps the live value through a draft apply");
                  end if;
               end;
            end;
         end;
      end loop;

      --  Every key is distinct, so Parse cannot route one setting's line to another.
      for Left in Files.Settings.Scalar_Setting loop
         for Right in Files.Settings.Scalar_Setting loop
            if Left /= Right then
               Assert
                 (Files.Settings.Scalar_Key (Left) /= Files.Settings.Scalar_Key (Right),
                  Files.Settings.Scalar_Key (Left) & " is a unique key");
            end if;
         end loop;
      end loop;
   end Test_Scalar_Settings_Round_Trip;
