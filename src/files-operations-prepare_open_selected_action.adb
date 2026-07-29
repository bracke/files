separate (Files.Operations)
   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
   is
      Items : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      elsif Items.Is_Empty then
         return Disabled (Model, "error.selection.empty");
      elsif Natural (Items.Length) > 1 then
         declare
            First_Path : Unbounded_String;
            First_Action : Files.Settings.Open_Action := Empty_Action;
            First_Action_Recorded : Boolean := False;
         begin
            for Item of Items loop
               if Item.Kind = Files.Types.Directory_Item then
                  Files.Model.Set_Error (Model, "error.open_action.multi_directory");
                  return
                    Make_Result
                      (Operation_Failed,
                       "error.open_action.multi_directory",
                       To_String (Item.Full_Path));
               end if;
            end loop;

            for Item of Items loop
               declare
                  Lookup : constant Files.Settings.Action_Lookup_Result :=
                    Files.Settings.Lookup_Open_Action (Settings, To_String (Item.Filetype), Modifiers);
               begin
                  if Length (First_Path) = 0 then
                     First_Path := Item.Full_Path;
                  end if;

                  if not Lookup.Found then
                     Files.Model.Set_Error (Model, To_String (Lookup.Error_Key));
                     return
                       Make_Result
                         (Operation_Missing_Open_Action,
                          To_String (Lookup.Error_Key),
                          To_String (Item.Full_Path));
                  elsif Files.Settings.Has_Unsafe_Placeholder_Usage (Lookup.Action) then
                     return Unsafe_Open_Action (Model, To_String (Item.Full_Path));
                  end if;

                  if not First_Action_Recorded then
                     First_Action :=
                       Files.Settings.Expand_Placeholders (Lookup.Action, To_String (Item.Full_Path));
                     First_Action_Recorded := True;
                  end if;
               end;
            end loop;

            Files.Model.Set_Error (Model, "");
            return Make_Result (Operation_Success, Path => To_String (First_Path), Action => First_Action);
         end;
      end if;

      declare
         Item : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
      begin
         if Item.Kind = Files.Types.Directory_Item then
            Files.Model.Set_Error (Model, "");
            return Make_Result (Operation_Success, Path => To_String (Item.Full_Path));
         end if;

         declare
            Lookup : constant Files.Settings.Action_Lookup_Result :=
              Files.Settings.Lookup_Open_Action (Settings, To_String (Item.Filetype), Modifiers);
         begin
            if not Lookup.Found then
               Files.Model.Set_Error (Model, To_String (Lookup.Error_Key));
               return
                 Make_Result
                   (Operation_Missing_Open_Action,
                    To_String (Lookup.Error_Key),
                    To_String (Item.Full_Path));
            elsif Files.Settings.Has_Unsafe_Placeholder_Usage (Lookup.Action) then
               return Unsafe_Open_Action (Model, To_String (Item.Full_Path));
            end if;

            declare
               Action : constant Files.Settings.Open_Action :=
                 Files.Settings.Expand_Placeholders (Lookup.Action, To_String (Item.Full_Path));
            begin
               Files.Model.Set_Error (Model, "");
               return Make_Result (Operation_Success, Path => To_String (Item.Full_Path), Action => Action);
            end;
         end;
      end;
   end Prepare_Open_Selected_Action;
