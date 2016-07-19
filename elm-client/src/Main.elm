module Main exposing (..)

import Html.App as App
import Html exposing (..)
import Html.Attributes exposing (value, placeholder, class)
import Html.Events exposing (onInput, onClick, onSubmit)
import Dict exposing (Dict)
import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push
import Phoenix.Presence exposing (PresenceState, syncState, syncDiff, presenceStateDecoder, presenceDiffDecoder)
import Json.Encode as JE
import Json.Decode as JD exposing ((:=))
import Dict exposing (Dict)
import Chat
import Debug


type alias Model =
    { chats : Dict Int Chat.Model
    , username : String
    , phxSocket : Maybe (Phoenix.Socket.Socket Msg)
    , phxPresences : PresenceState Chat.UserPresence
    , channelName : Maybe String
    , nextChatId : Int
    }


type Msg
    = JoinChannel
    | SetChannel String
    | PhoenixMsg (Phoenix.Socket.Msg Msg)
    | ReceiveChatMessage JE.Value
    | SetUsername String
    | ConnectSocket
    | HandlePresenceState JE.Value
    | HandlePresenceDiff JE.Value
    | ChatMsg Int Chat.Msg


initialModel : Model
initialModel =
    { chats = Dict.empty
    , username = ""
    , phxSocket = Nothing
    , phxPresences = Dict.empty
    , channelName = Nothing
    , nextChatId = 1
    }


socketServer : String -> String
socketServer username =
    "ws://localhost:4000/socket/websocket?username=" ++ username


initPhxSocket : String -> Phoenix.Socket.Socket Msg
initPhxSocket username =
    Phoenix.Socket.init (socketServer username)
        |> Phoenix.Socket.withDebug


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        JoinChannel ->
            case model.channelName of
                Nothing ->
                    model ! []

                Just channelName ->
                    case model.phxSocket of
                        Nothing ->
                            model ! []

                        Just modelPhxSocket ->
                            let
                                channel =
                                    Phoenix.Channel.init channelName

                                ( phxSocket, phxJoinCmd ) =
                                    Phoenix.Socket.join channel modelPhxSocket

                                phxSocket2 =
                                    Phoenix.Socket.on "new:msg" "channelName" ReceiveChatMessage phxSocket

                                initialChatModel =
                                    Chat.initialModel

                                newChat =
                                    { initialChatModel | topic = channelName }

                                newChats =
                                    model.chats
                                        |> Dict.insert model.nextChatId newChat
                            in
                                { model
                                    | phxSocket = Just phxSocket2
                                    , nextChatId = model.nextChatId + 1
                                    , chats = newChats
                                }
                                    ! [ Cmd.map PhoenixMsg phxJoinCmd ]

        SetChannel channelName ->
            { model | channelName = (Just channelName) } ! []

        SetUsername username ->
            { model | username = username } ! []

        ConnectSocket ->
            { model | phxSocket = Just (initPhxSocket model.username) } ! []

        HandlePresenceState raw ->
            model ! []

        HandlePresenceDiff raw ->
            model ! []

        PhoenixMsg _ ->
            model ! []

        ReceiveChatMessage _ ->
            model ! []

        ChatMsg chatId chatMsg ->
            let
                _ =
                    Debug.log "chatMsg: " chatMsg
            in
                case Dict.get chatId model.chats of
                    Nothing ->
                        model ! []

                    Just chatModel ->
                        let
                            ( chatModel, chatCmd ) =
                                Chat.update chatMsg chatModel

                            newChats =
                                Dict.insert chatId chatModel model.chats
                        in
                            handleRootChatMsg chatId chatMsg newChats chatCmd model


handleRootChatMsg chatId chatMsg newChats chatCmd model =
    case chatMsg of
        Chat.SendMessage ->
            model ! []

        _ ->
            { model | chats = newChats } ! [ Cmd.map (ChatMsg chatId) chatCmd ]


chatMessageDecoder : JD.Decoder Chat.ChatMessage
chatMessageDecoder =
    JD.object2 Chat.ChatMessage
        (JD.oneOf
            [ ("user" := JD.string)
            , JD.succeed "anonymous"
            ]
        )
        ("body" := JD.string)


userPresenceDecoder : JD.Decoder Chat.UserPresence
userPresenceDecoder =
    JD.object2 Chat.UserPresence
        ("online_at" := JD.string)
        ("device" := JD.string)


viewMessage : Chat.ChatMessage -> Html Msg
viewMessage message =
    div [ class "message" ]
        [ span [ class "user" ] [ text (message.user ++ ": ") ]
        , span [ class "body" ] [ text message.body ]
        ]


lobbyManagementView : Model -> Html Msg
lobbyManagementView model =
    case model.channelName of
        Nothing ->
            button [ onClick (SetChannel "room:lobby") ] [ text "Set channel to lobby" ]

        Just channelName ->
            button [ onClick JoinChannel ] [ text ("Join channel " ++ channelName) ]


chatViewListItem : ( Int, Chat.Model ) -> Html Msg
chatViewListItem ( chatId, chatModel ) =
    li [] [ App.map (ChatMsg chatId) (Chat.view chatModel) ]


chatsView : Model -> Html Msg
chatsView model =
    let
        chatViews =
            model.chats
                |> Dict.toList
                |> List.map chatViewListItem
    in
        ul [] chatViews


chatInterfaceView : Model -> Html Msg
chatInterfaceView model =
    div []
        [ lobbyManagementView model
        , chatsView model
        ]


setUsernameView : Html Msg
setUsernameView =
    form [ onSubmit ConnectSocket ]
        [ input [ onInput SetUsername, placeholder "Enter a username" ] [] ]


view : Model -> Html Msg
view model =
    case model.phxSocket of
        Nothing ->
            setUsernameView

        _ ->
            chatInterfaceView model


main : Program Never
main =
    App.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.phxSocket of
        Nothing ->
            Sub.none

        Just phxSocket ->
            Phoenix.Socket.listen phxSocket PhoenixMsg


init : ( Model, Cmd Msg )
init =
    ( initialModel, Cmd.none )
