with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

package body Files.Localization.Testing is

   function Render_With_Shard
     (Base, Shard, Locale, Key : String;
      Loaded                   : out Boolean)
      return String
   is
      use type Messages.Result.Render_Status;
      Item   : Messages.Runtime.Runtime;
      Args   : Messages.Arguments.Arguments;
      Result : Messages.Result.Render_Result;
   begin
      Loaded := False;
      Messages.Runtime.Initialize (Item, Base);
      if not Messages.Runtime.Is_Valid (Item) then
         Messages.Runtime.Finalize (Item);
         return "";
      end if;
      Loaded := Load_Locale_Shard (Item, Shard);
      if not Messages.Runtime.Is_Valid (Item) then
         Messages.Runtime.Finalize (Item);
         return "";
      end if;
      Result := Messages.Runtime.Render (Item, Locale, Key, Args);
      declare
         Text : constant String :=
           (if Result.Status = Messages.Result.Success then Messages.Result.Output_Text (Result.Text) else "");
      begin
         Messages.Runtime.Finalize (Item);
         return Text;
      end;
   end Render_With_Shard;

end Files.Localization.Testing;
