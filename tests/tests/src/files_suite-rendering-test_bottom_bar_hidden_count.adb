separate (Files_Suite.Rendering)
   --  Item 8/9 invariant: the bottom bar renders the localized hidden-count
   --  label carrying the snapshot's Hidden_Count, and exposes the count region
   --  as an accessible toggle button -- checked semantically, without exact
   --  pixels or colors.
   procedure Test_Bottom_Bar_Hidden_Count (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Contains (Haystack : String; Needle : String) return Boolean is
      begin
         if Needle'Length = 0 or else Needle'Length > Haystack'Length then
            return Needle'Length = 0;
         end if;

         for Start in Haystack'First .. Haystack'Last - Needle'Length + 1 loop
            if Haystack (Start .. Start + Needle'Length - 1) = Needle then
               return True;
            end if;
         end loop;

         return False;
      end Contains;

      Hidden_Word  : constant String := Files.Localization.Text ("status.hidden");
      Toggle_Name  : constant String :=
        Files.Localization.Text (Files.Commands.Name_Key (Files.Commands.Toggle_Hidden_Files_Command));
      Snapshot     : View_Snapshot := Sample_Snapshot (5, Files.Types.Small_Icons);
      Frame        : Frame_Commands;
      Status_Text  : Unbounded_String;
      Found_Status : Boolean := False;
      Found_Button : Boolean := False;
   begin
      Snapshot.Hidden_Count := 7;
      Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command) := True;
      Frame := Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);

      for Command of Frame.Text loop
         if Contains (To_String (Command.Text), Hidden_Word) then
            Status_Text  := Command.Text;
            Found_Status := True;
         end if;
      end loop;
      Assert (Found_Status, "the bottom bar renders the localized hidden-count label");
      Assert (Contains (To_String (Status_Text), "7"), "the hidden-count label reflects the snapshot hidden count");

      for Node of Frame.Accessibility loop
         if Node.Role = Role_Button and then To_String (Node.Name) = Toggle_Name then
            Found_Button := True;
         end if;
      end loop;
      Assert (Found_Button, "the bottom-bar hidden count is exposed as an accessible toggle button");
   end Test_Bottom_Bar_Hidden_Count;
