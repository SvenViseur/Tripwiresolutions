import groovyx.net.http.HTTPBuilder
import groovyx.net.http.RESTClient
import groovyx.net.http.HttpResponseDecorator
import groovy.json.JsonSlurper
import groovy.json.JsonOutput

// ContentType static import
import static groovyx.net.http.ContentType.*
// Method static import
import static groovyx.net.http.Method.*

        def http = new HTTPBuilder( 'https://digiwave.atlassian.net' )
        http.request( GET, JSON ) { req -> // 'req ->' is not present in your code snippet!
          uri.path = '/rest/api/2/issue/EST-291'
          uri.query = [ login:'systemteamesperanto@argenta.be', password: 'V1x07D7oyGPEvkIMfIefA0BA' ]

          response.success = { resp, xml ->
            def xmlResult = xml
          }
        }