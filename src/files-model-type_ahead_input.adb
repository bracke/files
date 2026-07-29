separate (Files.Model)
   procedure Type_Ahead_Input
     (Model   : in out Window_Model;
      Text    : String;
      Matched : out Boolean)
   is
      Combined : constant String := To_String (Model.Type_Ahead_Buffer_Value) & Text;
      Current  : constant Natural := Selected_Index (Model);
      Visible  : Files.File_System.Item_Vectors.Vector;
      Count    : constant Natural := Visible_Count (Model);
      Prefix   : Unbounded_String;
      Start    : Natural;
      Target   : Natural;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Matched := False;

      if not Is_Printable_Run (Text) then
         return;
      end if;

      --  Snapshot the visible projection in display order so the pure matcher's
      --  returned index maps straight back to a visible index. Temporary
      --  create-file items are never type-ahead targets.
      for Visible_Index in 1 .. Count loop
         if Visible_To_Item_Index (Model, Visible_Index) /= 0 then
            Visible.Append (Visible_Item (Model, Visible_Index));
         else
            Visible.Append (Files.File_System.Directory_Item'(others => <>));
         end if;
      end loop;

      --  Repeatedly typing one letter cycles through the items beginning with
      --  it: collapse the prefix to that single codepoint and scan from just
      --  after the current selection. Any other run refines in place, scanning
      --  from the current selection so an already-matching item is kept.
      if Is_Repeated_Single_Codepoint (Combined) then
         Prefix := To_Unbounded_String (First_Codepoint (Combined));
         Start := Current + 1;
      else
         Prefix := To_Unbounded_String (Combined);
         Start := Current;
      end if;

      Model.Type_Ahead_Buffer_Value := Prefix;

      Target := Files.Type_Ahead.Type_Ahead_Target (Visible, To_String (Prefix), Start);
      if Target > 0 then
         Select_Visible_Internal (Model, Target);
         Matched := True;
      end if;
   end Type_Ahead_Input;
