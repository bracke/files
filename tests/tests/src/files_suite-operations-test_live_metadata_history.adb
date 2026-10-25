separate (Files_Suite.Operations)
   procedure Test_Live_Metadata_History (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "live-source");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      use type Files.Types.Account_Id;
      Uid, Gid : Files.Types.Account_Id;
      Available : Boolean;
   begin
      if not Files.File_System.Supports_Permissions then
         Files_Suite.Support.Skip ("Test_Live_Metadata_History", "not Files.File_System.Supports_Permissions");
         return;
      end if;
      for Background in Boolean loop
         for Toggle in Boolean loop
            Reset_Root;
            Write_Binary_File (Source, "owned bytes");
            Mutation := Files.File_System.Set_Permissions (Source, 8#644#);
            Assert (Mutation.Success, "prepare cached permissions");
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Operations.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Select_Name (Model, "live-source");
            Mutation := Files.File_System.Set_Permissions (Source, 8#600#);
            Assert (Mutation.Success, "simulate a permission change after the directory listing");
            Step := (if Toggle then Files.Operations.Toggle_Permission_Bit (Model, 8, Settings)
                     else Files.Operations.Set_Permissions_For (Model, 8#750#, Settings));
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then Metadata_Mode_Of (Source) =
                      (if Hostkit.Metadata.Mode_Bits_Are_Native
                       then (if Toggle then 8#601# else 8#750#)
                       else (if Toggle then 8#600# else 8#640#)),
                    "permission changes and toggles use current mode bits");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success and then Metadata_Mode_Of (Source) = 8#600#,
                    "Undo restores the live previous mode instead of stale directory metadata");
         end loop;
         if Files.File_System.Supports_Ownership then
            Reset_Root;
            Write_Binary_File (Source, "owned bytes");
            Files.File_System.Ownership_Of (Source, Uid, Gid, Available);
            Assert (Available, "read actual ownership");
            Load := Files.File_System.Load_Directory (Root, Settings);
            declare
               Item : Files.File_System.Directory_Item := Load.Items.First_Element;
            begin
               Item.Owner_Id := (if Uid > 0 then Uid - 1 else 1);
               Item.Group_Id := (if Gid > 0 then Gid - 1 else 1);
               Load.Items.Replace_Element (Load.Items.First_Index, Item);
            end;
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Operations.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Select_Name (Model, "live-source");
            Step := Files.Operations.Set_Ownership_For (Model, Uid, Gid, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "change ownership with a stale cached owner");
            Assert
              (Ada.Strings.Fixed.Index
                 (To_String (Files.Model.Undo_To_Paths (Model).First_Element),
                  Files.Types.Account_Image (Uid) & " "
                  & Files.Types.Account_Image (Gid)
                  & String'(1 => Ada.Characters.Latin_1.NUL)) = 1,
                    "ownership history records the live ids rather than the stale item");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Undo applies the live ownership snapshot: status="
               & Files.Operations.Operation_Status'Image (Step.Status)
               & " uid=" & Files.Types.Account_Image (Uid)
               & " gid=" & Files.Types.Account_Image (Gid)
               & " background=" & Boolean'Image (Background));
         end if;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Live_Metadata_History;
