#import "PubnubPlugin.h"

@interface PubnubPlugin () <PNObjectEventListener>

@property (nonatomic, strong) NSMutableDictionary<NSString*, PubNub*> *clients;
@end

@implementation PubnubPlugin

NSString *const PUBNUB_METHOD_CHANNEL_NAME = @"flutter.ingenio.com/pubnub_plugin";
NSString *const PUBNUB_MESSAGE_CHANNEL_NAME = @"flutter.ingenio.com/pubnub_message";
NSString *const PUBNUB_STATUS_CHANNEL_NAME = @"flutter.ingenio.com/pubnub_status";
NSString *const PUBNUB_PRESENCE_CHANNEL_NAME = @"flutter.ingenio.com/pubnub_presence";
NSString *const PUBNUB_ERROR_CHANNEL_NAME = @"flutter.ingenio.com/pubnub_error";

NSString *const SUBSCRIBE_METHOD = @"subscribe";
NSString *const PUBLISH_METHOD = @"publish";
NSString *const PRESENCE_METHOD = @"presence";
NSString *const UNSUBSCRIBE_METHOD = @"unsubscribe";
NSString *const DISPOSE_METHOD = @"dispose";
NSString *const UUID_METHOD = @"uuid";

NSString *const CLIENT_ID_KEY = @"clientId";
NSString *const CHANNELS_KEY = @"channels";
NSString *const STATE_KEY = @"state";
NSString *const CHANNEL_KEY = @"channel";
NSString *const MESSAGE_KEY = @"message";
NSString *const METADATA_KEY = @"metadata";
NSString *const PUBLISH_CONFIG_KEY = @"publishKey";
NSString *const SUBSCRIBE_CONFIG_KEY = @"subscribeKey";
NSString *const AUTH_CONFIG_KEY = @"authKey";
NSString *const PRESENCE_TIMEOUT_KEY = @"presenceTimeout";
NSString *const UUID_KEY = @"uuid";
NSString *const FILTER_KEY = @"filter";
NSString *const ERROR_OPERATION_KEY = @"operation";
NSString *const ERROR_KEY = @"error";
NSString *const EVENT_KEY = @"event";
NSString *const OCCUPANCY_KEY = @"occupancy";
NSString *const STATUS_CATEGORY_KEY = @"category";
NSString *const STATUS_OPERATION_KEY = @"operation";

NSString *const MISSING_ARGUMENT_EXCEPTION = @"Missing Argument Exception";

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:PUBNUB_METHOD_CHANNEL_NAME
                                     binaryMessenger:[registrar messenger]];
    PubnubPlugin* instance = [[PubnubPlugin alloc] init];
    
    instance.messageStreamHandler = [MessageStreamHandler new];
    instance.statusStreamHandler = [StatusStreamHandler new];
    instance.presenceStreamHandler = [PresenceStreamHandler new];
    instance.errorStreamHandler = [ErrorStreamHandler new];
    
    [registrar addMethodCallDelegate:instance channel:channel];
    
    
    [[FlutterEventChannel eventChannelWithName:PUBNUB_MESSAGE_CHANNEL_NAME
                               binaryMessenger:[registrar messenger]] setStreamHandler:instance.messageStreamHandler];
    
    [[FlutterEventChannel eventChannelWithName:PUBNUB_STATUS_CHANNEL_NAME
                               binaryMessenger:[registrar messenger]] setStreamHandler:instance.statusStreamHandler];
    
    [[FlutterEventChannel eventChannelWithName:PUBNUB_PRESENCE_CHANNEL_NAME
                               binaryMessenger:[registrar messenger]] setStreamHandler:instance.presenceStreamHandler];
    
    [[FlutterEventChannel eventChannelWithName:PUBNUB_ERROR_CHANNEL_NAME
                               binaryMessenger:[registrar messenger]] setStreamHandler:instance.errorStreamHandler];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
    @try{
        NSString *clientId = call.arguments[CLIENT_ID_KEY];
        
        if ([DISPOSE_METHOD isEqualToString:call.method]) {
            result([self handleDispose:call clientId:clientId]);
        } else if  ([SUBSCRIBE_METHOD isEqualToString:call.method]) {
            result([self handleSubscribe:call clientId:clientId]);
        } else if  ([PUBLISH_METHOD isEqualToString:call.method]) {
            result([self handlePublish:call clientId:clientId]);
        } else if  ([PRESENCE_METHOD isEqualToString:call.method]) {
            result([self handlePresence:call clientId:clientId]);
        } else if  ([UNSUBSCRIBE_METHOD isEqualToString:call.method]) {
            result([self handleUnsubscribe:call clientId:clientId]);
        } else if  ([UUID_METHOD isEqualToString:call.method]) {
            result([self handleUUID:call clientId:clientId]);
        } else {
            result(FlutterMethodNotImplemented);
        }
    }
    @catch(NSException *exception){
        result([exception reason]);
    }
}

- (PubNub *) getClient:(NSString *)clientId call:(FlutterMethodCall *)call {
    if(self.clients == NULL) {
        self.clients = [NSMutableDictionary new];
    }
    
    if(self.clients[clientId] == NULL) {
        self.clients[clientId] = [self createClient:clientId call:call];
    }
    
    return self.clients[clientId];
}

- (PubNub *) createClient:(NSString *)clientId call:(FlutterMethodCall *)call {
    
    NSLog(@"FlutterPubnubPlugin createClient clientId: %@ method: %@", clientId, call.method);
    
    PNConfiguration *config = [self configFromCall:call];
    
    PubNub *client = [PubNub clientWithConfiguration:config];
    
    NSString *filter = call.arguments[FILTER_KEY];
    
    if((id)filter != [NSNull null] && filter && filter.length > 0) {
        NSLog(@"Setting filter expression");
        client.filterExpression = filter;
    }
    
    [client addListener:self];
    
    return client;
}

- (PNConfiguration *)configFromCall:(FlutterMethodCall*)call {
    NSString *publishKey = call.arguments[PUBLISH_CONFIG_KEY];
    
    NSLog(@"IN CONFIG FROM CALL");
    if((id)publishKey == [NSNull null] || publishKey == NULL) {
        NSLog(@"configFromCall: publish key is null");
        @throw [[MissingArgumentException alloc] initWithName:MISSING_ARGUMENT_EXCEPTION reason:@"Publish key can't be null or empty" userInfo:nil];
    }
    
    NSString *subscribeKey = call.arguments[SUBSCRIBE_CONFIG_KEY];
    if((id)subscribeKey == [NSNull null] || subscribeKey == NULL) {
        NSLog(@"configFromCall: subscribe key is null");
        @throw [[MissingArgumentException alloc] initWithName:MISSING_ARGUMENT_EXCEPTION reason:@"Subscribe key can't be null or empty" userInfo:nil];
    }
    
    id authKey = call.arguments[AUTH_CONFIG_KEY];
    id presenceTimeout = call.arguments[PRESENCE_TIMEOUT_KEY];
    id uuid = call.arguments[UUID_KEY];
    
    PNConfiguration *config =
    [PNConfiguration configurationWithPublishKey:publishKey
                                    subscribeKey:subscribeKey];
    
    if(uuid != [NSNull null]) {
        NSLog(@"configFromCall: setting uuid");
        config.uuid = uuid;
    }
    
    if(authKey != [NSNull null]) {
        NSLog(@"configFromCall: setting authkey: %@", authKey);
        config.authKey = authKey;
    }
    
    if(presenceTimeout != [NSNull null]) {
        NSLog(@"configFromCall: setting presence timeout: %ld", (long)[presenceTimeout integerValue]);
        config.presenceHeartbeatValue = [presenceTimeout integerValue];
    }
    
    NSLog(@"IN CONFIG FROM CALL END");
    
    return config;
}

- (id) handleUnsubscribe:(FlutterMethodCall*)call clientId:(NSString *)clientId {
    NSArray<NSString *> *channels = call.arguments[CHANNELS_KEY];
    
    PubNub *client = [self getClient:clientId call:call];
    
     if((id)channels == [NSNull null] || channels == NULL || [channels count] == 0) {
        NSLog(@"Unsubscribing from channels: %@", channels);
        [client unsubscribeFromChannels:channels withPresence:NO];
    } else {
        NSLog(@"Unsubscribing ALL Channels");
        [client unsubscribeFromAll];
    }
    
    return NULL;
}

- (id) handleDispose:(FlutterMethodCall*)call clientId:(NSString *)clientId {
    
    for(PubNub *client in [self.clients allValues]) {
        [client unsubscribeFromAll];
    }
    
    [self.clients removeAllObjects];
    
    return NULL;
}

- (id) handleUUID:(FlutterMethodCall*)call clientId:(NSString *)clientId {
    PubNub *client = [self getClient:clientId call:call];
    NSLog(@"UUID method: clientid: %@, client: %@", clientId, client);
    return [[client currentConfiguration] uuid];
}

- (id) handlePublish:(FlutterMethodCall*)call clientId:(NSString *)clientId {
    NSArray<NSString *> *channels = call.arguments[CHANNELS_KEY];
    NSDictionary *message = call.arguments[MESSAGE_KEY];
    NSDictionary *metadata = call.arguments[METADATA_KEY];
    
    if((id)channels == [NSNull null] || channels == NULL || [channels count] == 0) {
        @throw [[MissingArgumentException alloc] initWithName:MISSING_ARGUMENT_EXCEPTION reason:@"Publish channels can't be null or empty" userInfo:nil];
    }
    
    if((id)message == [NSNull null] || message == NULL || [message count] == 0) {
        @throw [[MissingArgumentException alloc] initWithName:MISSING_ARGUMENT_EXCEPTION reason:@"Publish message can't be null or empty" userInfo:nil];
    }
    
    PubNub *client = [self getClient:clientId call:call];
    
    __weak __typeof(self) weakSelf = self;
    
    for(NSString *channel in channels) {
        [client publish:message toChannel:channel withMetadata:metadata completion:^(PNPublishStatus *status) {
            __strong __typeof(self) strongSelf = weakSelf;
            [strongSelf handleStatus:status clientId:clientId];
        }];
    }
    
    return NULL;
}

- (id) handlePresence:(FlutterMethodCall*)call clientId:(NSString *)clientId {
    NSArray<NSString *> *channels = call.arguments[CHANNELS_KEY];
    NSDictionary<NSString*, NSString*> *state = call.arguments[STATE_KEY];
    
    if((id)channels == [NSNull null] || channels == NULL || [channels count] == 0) {
        @throw [[MissingArgumentException alloc] initWithName:MISSING_ARGUMENT_EXCEPTION reason:@"Presence channels can't be null or empty" userInfo:nil];
    }
    
    if((id)state == [NSNull null] || state == NULL || [state count] == 0) {
        @throw [[MissingArgumentException alloc] initWithName:MISSING_ARGUMENT_EXCEPTION reason:@"Presence state can't be null or empty" userInfo:nil];
    }
    
    PubNub *client = [self getClient:clientId call:call];
    
    for(NSString *channel in channels) {
        [client setState: state forUUID:client.uuid onChannel: channel
          withCompletion:^(PNClientStateUpdateStatus *status) {
          
          if (status.isError) {
              NSDictionary *result = @{CLIENT_ID_KEY: clientId, ERROR_OPERATION_KEY:  [PubnubPlugin getOperationAsNumber:status.operation], ERROR_KEY: @""};
              [self.errorStreamHandler sendError:result];
          } else {
              [self.statusStreamHandler sendStatus:status clientId:clientId];
          }
      }];
    }
    
    return NULL;
}
- (id) handleSubscribe:(FlutterMethodCall*)call clientId:(NSString *)clientId {
    NSArray<NSString *> *channels = call.arguments[CHANNELS_KEY];
    
    NSLog(@"Subscribe: %@", channels);
    if((id)channels == [NSNull null] || channels == NULL || [channels count] == 0) {
        NSLog(@"Empty Channels exception");
        @throw [[MissingArgumentException alloc] initWithName:MISSING_ARGUMENT_EXCEPTION reason:@"Publish channels can't be null or empty" userInfo:nil];
    }
    
    PubNub *client = [self getClient:clientId call:call];
    
    [client subscribeToChannels:channels withPresence:YES];
    
    return NULL;
}

- (void)handleStatus:(PNPublishStatus *)status clientId:(NSString *)clientId {
    if (status.isError) {
        NSDictionary *result = @{CLIENT_ID_KEY: clientId, ERROR_OPERATION_KEY:  [PubnubPlugin getOperationAsNumber:status.operation], ERROR_KEY: @""};
        [self.errorStreamHandler sendError:result];
        
    } else {
        [self.statusStreamHandler sendStatus:status clientId:clientId];
    }
}

- (NSString *) getClientId:(PubNub *) client {
    NSArray *matches = [self.clients allKeysForObject:client];
    if(matches && matches.count > 0) {
        return matches[0];
    }
    return NULL;
}

- (void)client:(PubNub *)client didReceiveStatus:(PNStatus *)status {
    NSLog(@"ClientCallback didReceiveStatus");
    [self.statusStreamHandler sendStatus:status clientId:[self getClientId:client]];
}

- (void)client:(PubNub *)client didReceiveMessage:(PNMessageResult *)message {
    NSLog(@"ClientCallback didReceiveMessage");
    [self.messageStreamHandler sendMessage:message clientId:[self getClientId:client]];
}

// New presence event handling.
- (void)client:(PubNub *)client didReceivePresenceEvent:(PNPresenceEventResult *)presence {
    NSLog(@"ClientCallback didReceivePresenceEvent");
    [self.presenceStreamHandler sendPresence:presence clientId:[self getClientId:client]];
}


+ (NSNumber *) getCategoryAsNumber:(PNStatusCategory) category {
    switch(category) {
            
        case PNUnknownCategory:
            return [NSNumber numberWithInt:0];
        case PNAcknowledgmentCategory:
            return [NSNumber numberWithInt:1];
        case PNAccessDeniedCategory:
            return [NSNumber numberWithInt:2];
        case PNTimeoutCategory:
            return [NSNumber numberWithInt:3];
        case PNNetworkIssuesCategory:
            return [NSNumber numberWithInt:4];
        case PNConnectedCategory:
            return [NSNumber numberWithInt:5];
        case PNReconnectedCategory:
            return [NSNumber numberWithInt:6];
        case PNDisconnectedCategory:
            return [NSNumber numberWithInt:7];
        case PNUnexpectedDisconnectCategory:
            return [NSNumber numberWithInt:8];
        case PNCancelledCategory:
            return [NSNumber numberWithInt:9];
        case PNBadRequestCategory:
            return [NSNumber numberWithInt:10];
        case PNMalformedFilterExpressionCategory:
            return [NSNumber numberWithInt:11];
        case PNMalformedResponseCategory:
            return [NSNumber numberWithInt:12];
        case PNDecryptionErrorCategory:
            return [NSNumber numberWithInt:13];
        case PNTLSConnectionFailedCategory:
            return [NSNumber numberWithInt:14];
        case PNTLSUntrustedCertificateCategory:
            return [NSNumber numberWithInt:15];
        case PNRequestMessageCountExceededCategory:
            return [NSNumber numberWithInt:16];
        case PNRequestURITooLongCategory:
            return [NSNumber numberWithInt:0];
    }
    
    return [NSNumber numberWithInt:0];
}

+ (NSNumber *)  getOperationAsNumber:(PNOperationType) operation {
    switch (operation) {
            
        case PNSubscribeOperation:
            return [NSNumber numberWithInt:1];
        case PNUnsubscribeOperation:
            return [NSNumber numberWithInt:2];
        case PNPublishOperation:
            return [NSNumber numberWithInt:3];
        case PNHistoryOperation:
            return [NSNumber numberWithInt:4];
        case PNHistoryForChannelsOperation:
            return [NSNumber numberWithInt:0];
        case PNDeleteMessageOperation:
            return [NSNumber numberWithInt:6];
        case PNWhereNowOperation:
            return [NSNumber numberWithInt:7];
        case PNHereNowGlobalOperation:
            return [NSNumber numberWithInt:0];
        case PNHereNowForChannelOperation:
            return [NSNumber numberWithInt:0];
        case PNHereNowForChannelGroupOperation:
            return [NSNumber numberWithInt:0];
        case PNHeartbeatOperation:
            return [NSNumber numberWithInt:8];
        case PNSetStateOperation:
            return [NSNumber numberWithInt:9];
        case PNGetStateOperation:
            return [NSNumber numberWithInt:20];
        case PNStateForChannelOperation:
            return [NSNumber numberWithInt:0];
        case PNStateForChannelGroupOperation:
            return [NSNumber numberWithInt:0];
        case PNAddChannelsToGroupOperation:
            return [NSNumber numberWithInt:10];
        case PNRemoveChannelsFromGroupOperation:
            return [NSNumber numberWithInt:11];
        case PNChannelGroupsOperation:
            return [NSNumber numberWithInt:12];
        case PNRemoveGroupOperation:
            return [NSNumber numberWithInt:13];
        case PNChannelsForGroupOperation:
            return [NSNumber numberWithInt:14];
        case PNPushNotificationEnabledChannelsOperation:
            return [NSNumber numberWithInt:15];
        case PNAddPushNotificationsOnChannelsOperation:
            return [NSNumber numberWithInt:16];
        case PNRemovePushNotificationsFromChannelsOperation:
            return [NSNumber numberWithInt:17];;
        case PNRemoveAllPushNotificationsOperation:
            return [NSNumber numberWithInt:18];
        case PNTimeOperation:
            return [NSNumber numberWithInt:19];
        default:
            return [NSNumber numberWithInt:0];
    }
}
@end


@implementation MessageStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    self.eventSink = eventSink;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

- (void) sendMessage:(PNMessageResult *)message clientId:(NSString *)clientId {
    if(self.eventSink) {
        NSDictionary *result = @{CLIENT_ID_KEY: clientId, UUID_KEY: message.uuid, CHANNEL_KEY: message.data.channel, MESSAGE_KEY: message.data.message};
        self.eventSink(result);
    }
}

@end

@implementation StatusStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    self.eventSink = eventSink;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

- (void) sendStatus:(PNStatus *)status clientId:(NSString *)clientId {
    NSLog(@"sendStatus (StatusStreamHandler), status: %@, clientId:%@, eventSink: %@", status, clientId, self.eventSink);
    if(self.eventSink) {
        
        NSArray<NSString *> *affectedChannels;
        if (status.category == PNConnectedCategory || status.category == PNReconnectedCategory) {
            PNSubscribeStatus *subscribeStatus = (PNSubscribeStatus *)status;
            affectedChannels = subscribeStatus.subscribedChannels;
        }
        
        self.eventSink(@{CLIENT_ID_KEY: clientId, STATUS_CATEGORY_KEY: [PubnubPlugin getCategoryAsNumber:status.category],STATUS_OPERATION_KEY: [PubnubPlugin getOperationAsNumber:status.operation], UUID_KEY: status.uuid, CHANNELS_KEY: affectedChannels == NULL ? @[] : affectedChannels});
    }
}

@end

@implementation PresenceStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    self.eventSink = eventSink;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

- (void) sendPresence:(PNPresenceEventResult *)presence clientId:(NSString *)clientId {
    if(self.eventSink) {
        NSLog(@"Presence state: %@", presence.data.presence.state);
        self.eventSink(@{CLIENT_ID_KEY: clientId, CHANNEL_KEY: presence.data.channel, EVENT_KEY: presence.data.presenceEvent, UUID_KEY: presence.data.presence.uuid, OCCUPANCY_KEY: presence.data.presence.occupancy, STATE_KEY: presence.data.presence.state == NULL ? [NSDictionary new] : presence.data.presence.state});
    }
}

@end

@implementation ErrorStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    self.eventSink = eventSink;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

- (void) sendError:(NSDictionary *)error {
    if(self.eventSink) {
        self.eventSink(error);
    }
}

@end

@implementation MissingArgumentException
@end
