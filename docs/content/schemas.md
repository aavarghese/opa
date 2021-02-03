---
title: Type Checking
kind: misc
weight: 2
---

## Using schemas to enhance the Rego type checker

You can provide an input schema and/or data schema(s) to `opa eval` to improve static type checking and get more precise error reports as you develop Rego code.
The `-s` flag can be used to upload schemas for the input document and/or for the data documents in JSON Schema format.

```
-s, --schema string set schema file path or directory path
```

Example:
```
opa eval data.envoy.authz.allow -i example/envoy/input.json -d example/envoy/policy.rego -s example/envoy/input-schema.json
```
Samples provided at: https://github.com/aavarghese/opa-schema-examples/tree/main/envoy



## Usage Scenario

Consider the following Rego code, which assumes as input a Kubernetes admission review. For resources that are `Pod`s, it checks that the image name
starts with a specific prefix.

`pod.rego`
```
package kubernetes.admission                                                

deny[msg] {                                                                
  input.request.kind.kinds == "Pod"                               
  image := input.request.object.spec.containers[_].image                    
  not startswith(image, "hooli.com/")                                       
  msg := sprintf("image '%v' comes from untrusted registry", [image])       
}
```

Notice that this code has a typo in it: `input.request.kind.kinds` is undefined and should have been `input.request.kind.kind`.

Consider the following input document:


`admission-review.json`
```
{
    "kind": "AdmissionReview",
    "request": {
      "kind": {
        "kind": "Pod",
        "version": "v1"
      },
      "object": {
        "metadata": {
          "name": "myapp"
        },
        "spec": {
          "containers": [
            {
              "image": "nginx",
              "name": "nginx-frontend"
            },
            {
              "image": "mysql",
              "name": "mysql-backend"
            }
          ]
        }
      }
    }
  }
  ```

  Clearly there are 2 image names that are in violation of the policy. However, when we evalute the erroneous Rego code against this input we obtain:
  ```
  % opa eval --format pretty -i admission-review.json -d pod.rego
  $ []
  ```

  The empty value returned is indistinguishable from a situation where the input did not violate the policy. This error is therefore causing the policy not to catch violating inputs appropriately.

  If we fix the Rego code and change`input.request.kind.kinds` to `input.request.kind.kind`, then we obtain the expected result:
  ```
  [
  "image 'nginx' comes from untrusted registry",
  "image 'mysql' comes from untrusted registry"
  ]
  ```

  With this feature, it is possible to pass a schema to `opa eval`, written in JSON Schema. Consider the admission review schema provided at:
  https://github.com/aavarghese/opa-schema-examples/blob/main/kubernetes/admission-schema.json

  We can pass this schema to the evaluator as follows:
  ```
  % opa eval --format pretty -i admission-review.json -d pod.rego -s admission-schema.json
  ```

  With the erroneous Rego code, we now obtain the following type error:
  ```
  1 error occurred: ../../aavarghese/opa-schema-examples/kubernetes/pod.rego:5: rego_type_error: undefined ref: input.request.kind.kinds
	input.request.kind.kinds
	                   ^
	                   have: "kinds"
	                   want (one of): ["kind" "version"]
  ```

  This indicates the error to the Rego developer right away, without having the need to observe the results of runs on actual data, thereby improving productivity.

## Using annotations on Rules to further enhance the Rego type checker

[Under Construction]

A rule can be annotated with a comment of the form:

#@rulesSchema=<expression>:data.schemas.<path-to-schema>,...,<expression>:data.schemas.<path-to-schema>
An expression is of the form <input|data>.field1. ... .fieldN

This annotation associates a schema (uploaded via OPA's `opa eval --schema`) with the corresponding expression. So it can be used to give a schema to the input or any data document. The type checker derives a Rego Object type for the schema and an appropriate entry is added to the type environment. This entry is removed upon exit from the rule.

Annotations allow overriding when a prefix of an expression has a type in the type environment (see example below).

Notice that currently the annotation needs to appear on the line immediately preceding the rule definition.

Examples:

Consider a directory named `schemas` with the following structure, uploaded via `opa eval --schema /Users/ansuvarghese/opa-schema-examples/schemas`

```
schemas
---> input.json
---> kubernetes
-------> pod-schema.json
```

```
package kubernetes.admission                                                

#@rulesSchema=input.request.object:schemas.kubernetes.pod-schema
deny[msg] {                                                              
  input.request.kind.kind == "Pod"                                          
  image := input.request.object.spec.containers[_].image                    
  not startswith(image, "hooli.com/")                                       
  msg := sprintf("image '%v' comes from untrusted registry", [image])       
}
```

The above rule annotation indicates that the input has a type derived from the input schema (`input.json`) [does not need to be specified in the annotation since it is implied], and that in addition, input.request.object has a type which is derived from the pod schema. The second annotation overrides the type in the first annotation for the path input.request.object. Notice that the order of annotations matter for overriding to work correctly.

## References

For more examples, please see https://github.com/aavarghese/opa-schema-examples

This contains samples for Envoy, Kubernetes, and Terraform including corresponding JSON Schemas. 

For a reference on JSON Schema please see: http://json-schema.org/understanding-json-schema/reference/index.html

## Limitations

Currently this feature admits schemas written in JSON Schema but does not support every feature available in this format. This is part of future work. 
In particular the following features are not yet suported:

* additional properties for objects
* pattern properties for objects
* additional items for arrays
* contains for arrays
* allOf, anyOf, oneOf, not
* enum
* if/then/else
