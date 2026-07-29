separate (Files.Model)
   procedure Toggle_Rename
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Rename_Active then
         if Is_Temporary_Rename (Model) then
            Cancel_Create_File (Model);
            if Model.Focus_Value = Files.Types.Focus_Rename_Input then
               Model.Focus_Value := Files.Types.Focus_None;
            end if;
            return;
         end if;

         Reset_Rename_State (Model);
         if Model.Focus_Value = Files.Types.Focus_Rename_Input then
            Model.Focus_Value := Files.Types.Focus_None;
         end if;
      elsif Rename_Is_Enabled (Model) then
         Clear_Overlay_State_For_Edit (Model);
         Model.Rename_Fields.Clear;
         declare
            Indexes : constant Natural_Vectors.Vector := Selected_Loaded_Indexes (Model);
         begin
            for Item_Index of Indexes loop
               declare
                  Name : constant String :=
                    To_String (Model.Items.Element (Positive (Item_Index)).Name);
               begin
                  Model.Rename_Fields.Append
                    (Rename_Field'
                       (Item_Index => Item_Index,
                        Value      => To_Unbounded_String (Name),
                        Cursor     => Caret_Before_Extension (Name)));
               end;
            end loop;
         end;

         if not Model.Rename_Fields.Is_Empty then
            Model.Rename_Active := True;
            Model.Focus_Value := Files.Types.Focus_Rename_Input;
         end if;
      end if;
   end Toggle_Rename;
