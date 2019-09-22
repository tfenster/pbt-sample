tableextension 50100 "Customer Share Details" extends Customer
{
    fields
    {
        field(50100; ShareID; Text[4])
        {
            DataClassification = AccountData;
        }
    }
}

pageextension 50101 "Customer Card Share Details" extends "Customer Card"
{
    layout
    {
        addafter(Name)
        {
            field(ShareID; ShareID)
            {
                ApplicationArea = All;
                Caption = 'Share ID';
            }
        }
    }

    actions
    {
        addfirst("&Customer")
        {


            action(GetData)
            {
                ApplicationArea = All;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Category9;
                Caption = 'Share Info';
                Image = PaymentForecast;
                RunPageOnRec = true;
                RunObject = page "Customer Share Details";
            }

        }
    }
}

page 50100 "Customer Share Details"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = Customer;
    Editable = false;

    layout
    {
        area(Content)
        {
            group(Details)
            {
                Caption = 'Share Details';
                field(ShareId; ShareID)
                {
                    ApplicationArea = All;
                    Caption = 'Share name';
                }
                field(SharePrice; PriceVar)
                {
                    ApplicationArea = All;
                    Caption = 'Current price';
                }
                field(Percentage; PercentageVar)
                {
                    ApplicationArea = All;
                    Caption = 'Change percent';
                }
                field(Open; OpenVar)
                {
                    ApplicationArea = All;
                    Caption = 'Opening price';
                }
                field(Low; LowVar)
                {
                    ApplicationArea = All;
                    Caption = 'Lowest price';
                }
                field(High; HighVar)
                {
                    ApplicationArea = All;
                    Caption = 'Highest price';
                }
            }
        }
    }

    actions
    { }

    trigger OnAfterGetCurrRecord()
    var
        TaskParameters: Dictionary of [Text, Text];
    begin
        PriceVar := 'Loading...';
        PercentageVar := 'Loading...';
        OpenVar := 'Loading...';
        HighVar := 'Loading...';
        Lowvar := 'Loading...';

        TaskParameters.Add('ShareID', ShareID);
        TaskParameters.Add('Element', PriceKey);
        CurrPage.EnqueueBackgroundTask(TaskPriceId, 50100, TaskParameters, 20000, PageBackgroundTaskErrorLevel::Warning);

        TaskParameters.Set('Element', PercentageKey);
        CurrPage.EnqueueBackgroundTask(TaskPercentageId, 50100, TaskParameters, 20000, PageBackgroundTaskErrorLevel::Warning);

        TaskParameters.Set('Element', OpenKey);
        CurrPage.EnqueueBackgroundTask(TaskOpenId, 50100, TaskParameters, 20000, PageBackgroundTaskErrorLevel::Warning);

        TaskParameters.Set('Element', HighKey);
        CurrPage.EnqueueBackgroundTask(TaskHighId, 50100, TaskParameters, 20000, PageBackgroundTaskErrorLevel::Warning);

        TaskParameters.Set('Element', LowKey);
        CurrPage.EnqueueBackgroundTask(TaskLowId, 50100, TaskParameters, 20000, PageBackgroundTaskErrorLevel::Warning);
    end;

    trigger OnPageBackgroundTaskCompleted(TaskId: Integer; Results: Dictionary of [Text, Text])
    begin
        if (TaskId = TaskPriceId) then begin
            PriceVar := Results.Get(PriceKey);
        end else
            if (TaskId = TaskPercentageId) then begin
                PercentageVar := Results.Get(PercentageKey);
            end else
                if (TaskId = TaskHighId) then begin
                    HighVar := Results.Get(HighKey);
                end else
                    if (TaskId = TaskLowId) then begin
                        LowVar := Results.Get(LowKey);
                    end else
                        if (TaskId = TaskOpenId) then begin
                            OpenVar := Results.Get(OpenKey);
                        end;
    end;

    trigger OnPageBackgroundTaskError(TaskId: Integer; ErrorCode: Text; ErrorText: Text; ErrorCallStack: Text; var IsHandled: Boolean)
    begin
        if (ErrorCode = 'JsonPropertyNotFound') then begin
            IsHandled := true;
            Error('Couldn''t find data for %1', ShareID);
        end;
    end;

    var
        PriceVar: Text[10];
        TaskPriceId: Integer;
        PriceKey: TextConst ENU = 'price';
        PercentageVar: Text[10];
        TaskPercentageId: Integer;
        PercentageKey: TextConst ENU = 'change_pct';
        HighVar: Text[10];
        TaskHighId: Integer;
        HighKey: TextConst ENU = 'day_high';
        LowVar: Text[10];
        TaskLowId: Integer;
        LowKey: TextConst ENU = 'day_low';
        OpenVar: Text[10];
        TaskOpenId: Integer;
        OpenKey: TextConst ENU = 'price_open';
}

codeunit 50100 PBTGetSharePrice
{
    TableNo = Customer;
    trigger OnRun()
    var
        Result: Dictionary of [Text, Text];
        WebServiceKey: Text;
        BaseURI: Text;
        HttpClient: HttpClient;
        HttpResponseMessage: HttpResponseMessage;
        ContentString: Text;
        ContentToken: JsonToken;
        QuoteToken: JsonToken;
        QuoteArrayToken: JsonToken;
        ValueToken: JsonToken;
        ShareId: Text[4];
        ElementValue: Text;
        ElementKey: Text;
    begin
        ShareId := Page.GetBackgroundParameters().Get('ShareID');
        ElementKey := Page.GetBackgroundParameters().Get('Element');
        if (ShareId <> '') then begin
            WebServiceKey := '<add api token here>';
            BaseURI := 'https://api.worldtradingdata.com/api/v1/stock?api_token=' + WebServiceKey;
            HttpClient.Get(BaseURI + '&symbol=' + ShareId, HttpResponseMessage);

            if (not HttpResponseMessage.IsSuccessStatusCode) then
                Error('Couldn''t retrieve the share data');

            HttpResponseMessage.Content().ReadAs(ContentString);
            ContentToken.ReadFrom(ContentString);
            ContentToken.AsObject().Get('data', QuoteArrayToken);
            QuoteArrayToken.AsArray().Get(0, QuoteToken);
            QuoteToken.AsObject().Get(Page.GetBackgroundParameters().Get('Element'), ValueToken);
            ElementValue := ValueToken.AsValue().AsText();
            Sleep((Random(5)) * 1000);
        end;

        Result.Add(ElementKey, ElementValue);
        Page.SetBackgroundTaskResult(Result);
    end;
}
